import Foundation
import Supabase

/// Posts service. Owns the queries for the feed; views never touch the
/// Supabase client directly.
struct FeedService {
    let client: SupabaseClient

    /// Placeholder for the eventual feed query. Will be expanded once the
    /// schema/policies for posts are settled.
    func recentPosts(limit: Int = 20) async throws -> [PostDTO] {
        []
    }
}

struct PostDTO: Decodable, Identifiable {
    let id: UUID
    let authorID: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorID = "author_id"
        case body
        case createdAt = "created_at"
    }
}
