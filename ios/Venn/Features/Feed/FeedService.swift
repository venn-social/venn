import Foundation
import Supabase

/// Feed read surface. Behind a protocol so view-models can be unit-tested
/// with a hand-rolled fake (we don't mock Supabase). Posting and reacting
/// land in follow-up PRs once the composer is designed.
protocol FeedServicing: Sendable {
    /// Recent posts from people the signed-in user follows (plus their
    /// own), newest first. Capped at `limit` rows. Includes each post's
    /// media and author profile so callers get the full render shape.
    ///
    /// `before` is the pagination cursor: pass the `createdAt` of the last
    /// post already shown to fetch the next page (strictly older posts).
    /// `nil` fetches the first page. Keyset-on-created_at rides the
    /// existing `posts_created_at_idx` and never duplicates rows when new
    /// posts land between pages, unlike an offset.
    ///
    /// Without a session (previews, DEBUG design boot) this degrades to
    /// the global feed rather than failing — there's no graph to scope to.
    func recentPosts(limit: Int, before: Date?) async throws -> [FeedPost]

    /// Log a feed item straight into your own collection.
    ///
    /// A plain upsert: `posts` is unique on (author_id, media_id), and
    /// promoting something you had saved into something you have consumed
    /// is exactly what this should do.
    func logFromFeed(authorID: UUID, mediaID: UUID) async throws

    /// Put a feed item on your own watchlist without disturbing an entry
    /// you already have.
    ///
    /// Insert-if-absent, unlike `logFromFeed`. A plain upsert here would
    /// quietly demote a film you rated five stars back to "saved" — the one
    /// outcome nobody wants from tapping "Add to Watchlist".
    func saveToWatchlist(authorID: UUID, mediaID: UUID) async throws
}

/// Production implementation backed by Supabase Postgrest. Funnels
/// third-party errors through `AppError.from(_:)` so callers see a single
/// semantic error type — same pattern as `ProfileService` (ADR 0006).
struct FeedService: FeedServicing {
    let client: SupabaseClient

    func logFromFeed(authorID: UUID, mediaID: UUID) async throws {
        try await writePost(authorID: authorID, mediaID: mediaID, action: .logged, ignoringExisting: false)
    }

    func saveToWatchlist(authorID: UUID, mediaID: UUID) async throws {
        try await writePost(authorID: authorID, mediaID: mediaID, action: .saved, ignoringExisting: true)
    }

    /// One row per (author, media), so both entry points upsert. Only the
    /// watchlist path ignores an existing row; see the protocol for why.
    private func writePost(
        authorID: UUID,
        mediaID: UUID,
        action: PostAction,
        ignoringExisting: Bool
    ) async throws {
        do {
            try await client
                .from("posts")
                .upsert(
                    FeedPostWritePayload(authorID: authorID, mediaID: mediaID, action: action),
                    onConflict: "author_id,media_id",
                    ignoreDuplicates: ignoringExisting
                )
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func recentPosts(limit: Int, before: Date?) async throws -> [FeedPost] {
        do {
            guard let viewerID = try? await client.auth.session.user.id else {
                return try await globalPosts(limit: limit, before: before)
            }
            let followees: [FolloweeRow] = try await client
                .from("follows")
                .select("followee_id")
                .eq("follower_id", value: viewerID)
                .execute()
                .value
            // Two round trips (graph, then posts) keeps the proven embed
            // query shape. Fine while follow counts are double-digit; past
            // a few hundred the in-list bloats the URL — that's the cue to
            // move this into an RPC (docs/TECH_DEBT.md).
            let authorIDs = followees.map(\.followeeId) + [viewerID]
            var query = client
                .from("posts")
                // The FK is named explicitly, and must stay that way:
                // post_likes references both posts and profiles, so
                // PostgREST also sees it as a many-to-many join between
                // them. A bare `author:profiles(*)` is ambiguous and fails
                // with PGRST201 — this broke the feed when likes shipped.
                .select("*, media(*), author:profiles!posts_author_id_fkey(*)")
                .in("author_id", values: authorIDs)
            if let before {
                query = query.lt("created_at", value: Self.cursor(before))
            }
            let rows: [FeedPostRow] = try await query
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.compactMap(FeedPost.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }

    private func globalPosts(limit: Int, before: Date?) async throws -> [FeedPost] {
        var query = client
            .from("posts")
            .select("*, media(*), author:profiles!posts_author_id_fkey(*)")
        if let before {
            query = query.lt("created_at", value: Self.cursor(before))
        }
        let rows: [FeedPostRow] = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap(FeedPost.init(row:))
    }

    /// Serializes the cursor date the way Postgres expects a `timestamptz`
    /// literal. Fractional seconds matter: without them every post created
    /// in the same second as the cursor would be skipped. Built per call —
    /// `ISO8601DateFormatter` isn't Sendable, so a shared static is illegal
    /// under strict concurrency, and this runs once per page fetch.
    private static func cursor(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

/// Wire-format row for the follow-graph fetch — just the followee column.
struct FolloweeRow: Decodable, Equatable {
    let followeeId: UUID

    enum CodingKeys: String, CodingKey {
        case followeeId = "followee_id"
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

/// Wire shape for logging or saving something already in `public.media`.
/// Rating and caption are deliberately absent — this is the one-tap path
/// from a feed row, and the composer is where those get set.
private struct FeedPostWritePayload: Encodable {
    let authorId: UUID
    let mediaId: UUID
    let action: String

    enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case mediaId = "media_id"
        case action
    }

    init(authorID: UUID, mediaID: UUID, action: PostAction) {
        authorId = authorID
        mediaId = mediaID
        self.action = action.rawValue
    }
}
