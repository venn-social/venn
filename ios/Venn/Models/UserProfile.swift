import Foundation

/// Decodable mirror of `public.profiles`. See the SQL definition in
/// `supabase/migrations/20260425120000_init.sql`.
///
/// Lives in `Models/` because more than one feature reads profiles (Auth,
/// Profile, Feed for post authors).
struct UserProfile: Decodable, Identifiable, Equatable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarURL: URL?
    let bio: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bio
        case createdAt = "created_at"
    }
}
