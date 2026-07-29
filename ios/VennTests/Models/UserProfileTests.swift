import Foundation
import Testing
@testable import Venn

/// `isPrivate` decodes leniently because the private-accounts migration
/// (`20260626120000_private_accounts.sql`) hasn't been pushed to the live
/// database yet — today's real API responses don't include the column.
/// These pin that fallback so it can't regress silently once the migration
/// does land and the field starts arriving for real.
struct UserProfileTests {
    @Test
    func decodesWithIsPrivateAbsentDefaultingToFalse() throws {
        // The exact shape production returns today, pre-migration.
        let json = Data("""
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "username": "ada",
            "display_name": "Ada Lovelace",
            "avatar_url": null,
            "bio": null,
            "created_at": "2026-05-01T00:00:00Z"
        }
        """.utf8)

        let profile = try decoder().decode(UserProfile.self, from: json)

        #expect(profile.isPrivate == false)
    }

    @Test
    func decodesWithIsPrivateTrue() throws {
        let json = Data("""
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "username": "ada",
            "display_name": null,
            "avatar_url": null,
            "bio": null,
            "is_private": true,
            "created_at": "2026-05-01T00:00:00Z"
        }
        """.utf8)

        let profile = try decoder().decode(UserProfile.self, from: json)

        #expect(profile.isPrivate == true)
    }

    @Test
    func decodesWithIsPrivateFalse() throws {
        let json = Data("""
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "username": "ada",
            "display_name": null,
            "avatar_url": null,
            "bio": null,
            "is_private": false,
            "created_at": "2026-05-01T00:00:00Z"
        }
        """.utf8)

        let profile = try decoder().decode(UserProfile.self, from: json)

        #expect(profile.isPrivate == false)
    }

    @Test
    func memberwiseInitDefaultsIsPrivateToFalse() {
        let profile = UserProfile(
            id: UUID(),
            username: "ada",
            displayName: nil,
            avatarURL: nil,
            bio: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )

        #expect(profile.isPrivate == false)
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
