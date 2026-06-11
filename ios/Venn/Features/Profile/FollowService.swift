import Foundation
import Supabase

/// Follow-graph reads and writes on the `follows` directed-edge table.
/// Behind a protocol so view-models unit-test with a fake (ADR 0005).
///
/// RLS (from the media_and_posts migration): the graph is public to read;
/// inserts/deletes only as yourself (`auth.uid() = follower_id`).
protocol FollowServicing: Sendable {
    /// Whether `followerID` currently follows `followeeID`.
    func isFollowing(followerID: UUID, followeeID: UUID) async throws -> Bool

    /// Create the edge. Idempotent: following someone you already follow
    /// succeeds (the duplicate-key violation is swallowed).
    func follow(followerID: UUID, followeeID: UUID) async throws

    /// Delete the edge. Idempotent by nature — deleting a non-existent
    /// edge matches zero rows and succeeds.
    func unfollow(followerID: UUID, followeeID: UUID) async throws

    /// Profiles that follow `userID`, newest edge first.
    func followers(of userID: UUID, limit: Int) async throws -> [UserProfile]

    /// Profiles that `userID` follows, newest edge first.
    func following(of userID: UUID, limit: Int) async throws -> [UserProfile]
}

/// Production implementation backed by Supabase Postgrest. Funnels
/// third-party errors through `AppError.from(_:)` (ADR 0006).
struct FollowService: FollowServicing {
    /// Postgres duplicate-key SQLSTATE — raised when the (follower,
    /// followee) edge already exists. Treated as success in `follow`.
    private static let uniqueViolation = "23505"

    let client: SupabaseClient

    func isFollowing(followerID: UUID, followeeID: UUID) async throws -> Bool {
        do {
            let count = try await client
                .from("follows")
                .select("*", head: true, count: .exact)
                .eq("follower_id", value: followerID)
                .eq("followee_id", value: followeeID)
                .execute()
                .count ?? 0
            return count > 0
        } catch {
            throw AppError.from(error)
        }
    }

    func follow(followerID: UUID, followeeID: UUID) async throws {
        do {
            try await client
                .from("follows")
                .insert(FollowInsertPayload(followerId: followerID, followeeId: followeeID))
                .execute()
        } catch let error as PostgrestError where error.code == Self.uniqueViolation {
            // Already following — the state the user asked for. Success.
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

    func followers(of userID: UUID, limit: Int = 50) async throws -> [UserProfile] {
        do {
            let rows: [FollowerRow] = try await client
                .from("follows")
                .select("created_at, follower:profiles!follows_follower_id_fkey(*)")
                .eq("followee_id", value: userID)
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
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.map(\.followee)
        } catch {
            throw AppError.from(error)
        }
    }
}

// MARK: - Wire format (internal for decode tests)

/// One `follows` row with the follower profile embedded. The explicit
/// FK name disambiguates the join — `follows` has two foreign keys into
/// `profiles` (follower_id and followee_id).
struct FollowerRow: Decodable {
    let follower: UserProfile
}

struct FollowingRow: Decodable {
    let followee: UserProfile
}

private struct FollowInsertPayload: Encodable {
    let followerId: UUID
    let followeeId: UUID

    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followeeId = "followee_id"
    }
}
