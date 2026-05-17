import Foundation
import Supabase

/// Feed read surface. Behind a protocol so view-models can be unit-tested
/// with a hand-rolled fake (we don't mock Supabase). Posting and reacting
/// land in follow-up PRs once the composer is designed.
protocol FeedServicing: Sendable {
    /// Recent posts across the entire graph, newest first. Capped at
    /// `limit` rows. Includes each post's media and author profile so
    /// callers get the full render shape in one round-trip.
    ///
    /// Today this is a global feed (no follow-graph filter) because there
    /// is no signed-in state most of the time. When auth is the default
    /// path, this will narrow to "people you follow + you" via a server-
    /// side RPC; the protocol contract won't change.
    func recentPosts(limit: Int) async throws -> [FeedPost]
}

/// Production implementation backed by Supabase Postgrest. Funnels
/// third-party errors through `AppError.from(_:)` so callers see a single
/// semantic error type — same pattern as `ProfileService` (ADR 0006).
struct FeedService: FeedServicing {
    let client: SupabaseClient

    func recentPosts(limit: Int = 20) async throws -> [FeedPost] {
        do {
            let rows: [FeedPostRow] = try await client
                .from("posts")
                .select("*, media(*), author:profiles(*)")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.compactMap(FeedPost.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }
}

/// Wire-format row for the joined feed query. Mirrors `posts` columns
/// plus the embedded `media` and `author` selections so the whole feed
/// item arrives in one decode.
struct FeedPostRow: Decodable, Equatable {
    let id: UUID
    let authorId: UUID
    let mediaId: UUID
    let action: String
    let rating: Double?
    let caption: String?
    let createdAt: Date
    let media: MediaSchema.Row
    let author: UserProfile

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case mediaId = "media_id"
        case action
        case rating
        case caption
        case createdAt = "created_at"
        case media
        case author
    }
}

extension FeedPost {
    /// Lift a service-layer joined row into the domain `FeedPost`.
    /// Returns nil if any enum field has an unknown raw value — keeps
    /// the feed forwards-compatible with new media kinds / actions
    /// added server-side ahead of a client release.
    init?(row: FeedPostRow) {
        guard let media = Media(row: row.media),
              let action = PostAction(rawValue: row.action)
        else { return nil }

        post = Post(
            id: row.id,
            authorID: row.authorId,
            mediaID: row.mediaId,
            action: action,
            rating: row.rating,
            caption: row.caption,
            createdAt: row.createdAt
        )
        self.media = media
        author = row.author
    }
}
