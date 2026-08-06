import Foundation
import Supabase

/// Fetch one post by id.
///
/// Separate from `FeedServicing` because it answers a different question:
/// the feed is scoped by the follow graph and paged, this is a permalink
/// lookup with neither. Mirrors web's `lib/post.ts`, which split for the
/// same reason.
///
/// Needed by notifications: a row knows the post's id and nothing else, and
/// `PostDetailView` wants the whole `FeedPost`.
protocol PostLookupServicing: Sendable {
    /// Nil when the post doesn't exist, or RLS won't show it to this
    /// viewer — a notification can outlive the post that caused it.
    func post(id: UUID) async throws -> FeedPost?
}

struct PostLookupService: PostLookupServicing {
    let client: SupabaseClient

    func post(id: UUID) async throws -> FeedPost? {
        do {
            // The author FK is named for the same reason it is in
            // `FeedService`: post_likes makes `posts`→`profiles` ambiguous,
            // and a bare embed fails with PGRST201.
            let rows: [FeedPostRow] = try await client
                .from("posts")
                .select("*, media(*), author:profiles!posts_author_id_fkey(*)")
                .eq("id", value: id)
                .limit(1)
                .execute()
                .value
            return rows.first.flatMap(FeedPost.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }
}
