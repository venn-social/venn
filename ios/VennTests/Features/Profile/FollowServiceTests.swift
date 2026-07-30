import Foundation
import Testing
@testable import Venn

/// Decode tests for the follow-list wire rows. The embedded-resource
/// aliases (`follower:` / `followee:`) must match the select strings in
/// `FollowService` — these tests pin the JSON shape PostgREST returns.
struct FollowServiceTests {
    @Test
    func decodesFollowerRow() throws {
        let json = Data("""
        {
            "created_at": "2026-06-01T12:00:00Z",
            "follower": {
                "id": "11111111-1111-1111-1111-111111111111",
                "username": "ada",
                "display_name": "Ada Lovelace",
                "avatar_url": null,
                "bio": null,
                "created_at": "2026-05-01T00:00:00Z"
            }
        }
        """.utf8)

        let row = try decoder().decode(FollowerRow.self, from: json)

        #expect(row.follower.username == "ada")
        #expect(row.follower.displayName == "Ada Lovelace")
    }

    @Test
    func decodesFollowingRow() throws {
        let json = Data("""
        {
            "created_at": "2026-06-01T12:00:00Z",
            "followee": {
                "id": "22222222-2222-2222-2222-222222222222",
                "username": "maya",
                "display_name": null,
                "avatar_url": null,
                "bio": null,
                "created_at": "2026-05-01T00:00:00Z"
            }
        }
        """.utf8)

        let row = try decoder().decode(FollowingRow.self, from: json)

        #expect(row.followee.username == "maya")
        #expect(row.followee.displayName == nil)
    }

    @Test
    func decodesFollowStatusRowPending() throws {
        let json = Data(#"{"status": "pending"}"#.utf8)

        let row = try decoder().decode(FollowStatusRow.self, from: json)

        #expect(row.status == "pending")
        #expect(FollowStatus(rawValue: row.status) == .pending)
    }

    @Test
    func decodesFollowStatusRowAccepted() throws {
        let json = Data(#"{"status": "accepted"}"#.utf8)

        let row = try decoder().decode(FollowStatusRow.self, from: json)

        #expect(FollowStatus(rawValue: row.status) == .accepted)
    }

    @Test
    func unknownFollowStatusRawValueMapsToNil() {
        // Forwards-compat: an unrecognized status (a future migration adds
        // a case the client doesn't know about yet) fails closed rather
        // than crashing.
        #expect(FollowStatus(rawValue: "blocked") == nil)
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
