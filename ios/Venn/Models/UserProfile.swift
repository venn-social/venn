import Foundation

/// Decodable mirror of `public.profiles`. See the SQL definition in
/// `supabase/migrations/20260425120000_init.sql`, plus `is_private` from
/// `20260626120000_private_accounts.sql`.
///
/// Lives in `Models/` because more than one feature reads profiles (Auth,
/// Profile, Feed for post authors).
struct UserProfile: Decodable, Identifiable, Equatable, Hashable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarURL: URL?
    let bio: String?
    let isPrivate: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case bio
        case isPrivate = "is_private"
        case createdAt = "created_at"
    }

    /// `isPrivate` decodes leniently (defaults to `false`, the column's own
    /// DB default): the private-accounts migration hasn't been pushed to
    /// the live database yet, so today's real API responses don't include
    /// it. This keeps the client working unchanged before *and* after that
    /// migration lands — no coordinated deploy required.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        avatarURL = try container.decodeIfPresent(URL.self, forKey: .avatarURL)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    init(
        id: UUID,
        username: String,
        displayName: String?,
        avatarURL: URL?,
        bio: String?,
        isPrivate: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.bio = bio
        self.isPrivate = isPrivate
        self.createdAt = createdAt
    }
}
