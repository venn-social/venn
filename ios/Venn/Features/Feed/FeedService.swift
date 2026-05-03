import Foundation
import Supabase

/// Posts service. Owns the queries for the feed; views never touch the
/// Supabase client directly.
struct FeedService {
    let client: SupabaseClient

    /// Placeholder for the eventual feed query. Will be expanded once the
    /// schema/policies for posts are settled.
    func recentPosts(limit: Int = 20) async throws -> [PostDTO] {
        _ = limit
        return []
    }
}

/// Decodable mirror of `public.posts`. See the SQL definition in
/// `supabase/migrations/20260425120000_init.sql`. Field names match the
/// Postgres column names via `CodingKeys`.
struct PostDTO: Decodable, Identifiable, Equatable {
    let id: UUID
    let authorID: UUID
    let caption: String
    let mediaURL: URL?
    let likeCount: Int
    let commentCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorID = "author_id"
        case caption
        case mediaURL = "media_url"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
    }
}
