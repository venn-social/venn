import Foundation
import Supabase

/// The result of asking to follow someone, per `request_follow`: instant for
/// a public account, pending approval for a private one.
enum FollowStatus: String, Codable, Equatable {
    case pending
    case accepted
}

/// Follow-graph reads and writes on the `follows` directed-edge table.
/// Behind a protocol so view-models unit-test with a fake (ADR 0005).
///
/// Writes go through RPCs, not direct inserts (`20260626120000_private_accounts.sql`
/// dropped `follows_insert_own`): `request_follow` is the only way to create
/// an edge, and it decides pending vs. accepted server-side based on the
/// target's privacy — the client never gets to assert "accepted" for a
/// private target.
protocol FollowServicing: Sendable {
    /// The edge's status if one exists (`follower` → `followee`), else `nil`.
    func followStatus(followerID: UUID, followeeID: UUID) async throws -> FollowStatus?

    /// Ask to follow `followeeID`. Returns `.accepted` for a public account
    /// (the edge exists immediately) or `.pending` for a private one (the
    /// followee must approve via `respondToRequest`).
    func requestFollow(followerID: UUID, followeeID: UUID) async throws -> FollowStatus

    /// Delete the edge — unfollowing an accepted edge, or withdrawing /
    /// declining a pending one. Idempotent: deleting a non-existent edge
    /// matches zero rows and succeeds.
    func unfollow(followerID: UUID, followeeID: UUID) async throws

    /// Accept or reject a pending request. Only the followee (`self`) may
    /// call this for their own incoming requests — enforced server-side.
    func respondToRequest(followerID: UUID, followeeID: UUID, accept: Bool) async throws

    /// Accepted followers of `userID`, newest edge first.
    func followers(of userID: UUID, limit: Int) async throws -> [UserProfile]

    /// Who `userID` accepted-follows, newest edge first.
    func following(of userID: UUID, limit: Int) async throws -> [UserProfile]

    /// People who've asked to follow `userID` and are awaiting approval,
    /// newest request first. Only meaningful for the signed-in user's own
    /// id — RLS only exposes another account's pending edges to themselves.
    func pendingRequests(for userID: UUID, limit: Int) async throws -> [UserProfile]
}

/// Production implementation backed by Supabase Postgrest + RPCs. Funnels
/// third-party errors through `AppError.from(_:)` (ADR 0006).
struct FollowService: FollowServicing {
    let client: SupabaseClient

    func followStatus(followerID: UUID, followeeID: UUID) async throws -> FollowStatus? {
        do {
            let rows: [FollowStatusRow] = try await client
                .from("follows")
                .select("status")
                .eq("follower_id", value: followerID)
                .eq("followee_id", value: followeeID)
                .limit(1)
                .execute()
                .value
            guard let raw = rows.first?.status else { return nil }
            return FollowStatus(rawValue: raw)
        } catch {
            throw AppError.from(error)
        }
    }

    func requestFollow(followerID _: UUID, followeeID: UUID) async throws -> FollowStatus {
        do {
            let raw: String = try await client
                .rpc("request_follow", params: ["target": followeeID])
                .execute()
                .value
            guard let status = FollowStatus(rawValue: raw) else {
                throw AppError.unknown(message: "request_follow returned unexpected status: \(raw)")
            }
            return status
        } catch {
            throw AppError.from(error)
        }
    }

    func unfollow(followerID: UUID, followeeID: UUID) async throws {
        do {
            try await client
                .from("follows")
                .delete()
                .eq("follower_id", value: followerID)
                .eq("followee_id", value: followeeID)
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func respondToRequest(followerID: UUID, followeeID _: UUID, accept: Bool) async throws {
        do {
            try await client
                .rpc(
                    "respond_to_follow_request",
                    params: RespondToRequestPayload(requester: followerID, accept: accept)
                )
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func followers(of userID: UUID, limit: Int = 50) async throws -> [UserProfile] {
        do {
            let rows: [FollowerRow] = try await client
                .from("follows")
                .select("created_at, follower:profiles!follows_follower_id_fkey(*)")
                .eq("followee_id", value: userID)
                .eq("status", value: FollowStatus.accepted.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.map(\.follower)
        } catch {
            throw AppError.from(error)
        }
    }

    func following(of userID: UUID, limit: Int = 50) async throws -> [UserProfile] {
        do {
            let rows: [FollowingRow] = try await client
                .from("follows")
                .select("created_at, followee:profiles!follows_followee_id_fkey(*)")
                .eq("follower_id", value: userID)
                .eq("status", value: FollowStatus.accepted.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.map(\.followee)
        } catch {
            throw AppError.from(error)
        }
    }

    func pendingRequests(for userID: UUID, limit: Int = 50) async throws -> [UserProfile] {
        do {
            let rows: [FollowerRow] = try await client
                .from("follows")
                .select("created_at, follower:profiles!follows_follower_id_fkey(*)")
                .eq("followee_id", value: userID)
                .eq("status", value: FollowStatus.pending.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.map(\.follower)
        } catch {
            throw AppError.from(error)
        }
    }
}

// MARK: - Wire format (internal for decode tests)

struct FollowStatusRow: Decodable, Equatable {
    let status: String
}

private struct RespondToRequestPayload: Encodable {
    let requester: UUID
    let accept: Bool
}

/// One `follows` row with the follower profile embedded. The explicit
/// FK name disambiguates the join — `follows` has two foreign keys into
/// `profiles` (follower_id and followee_id).
struct FollowerRow: Decodable {
    let follower: UserProfile
}

struct FollowingRow: Decodable {
    let followee: UserProfile
}
