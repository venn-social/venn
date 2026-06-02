import Foundation
import Supabase

/// Profile read + edit surface. Behind a protocol so view-models can be
/// unit-tested with a hand-rolled fake. Avatar upload (Supabase Storage) and
/// handle/username editing (uniqueness collision UX) land in follow-up PRs.
protocol ProfileServicing: Sendable {
    /// Fetch the profile row for `userID`. Throws when the row is missing
    /// (i.e. the auth user exists but the trigger that creates the
    /// matching `public.profiles` row hasn't run yet).
    func profile(for userID: UUID) async throws -> UserProfile

    /// Update editable fields on the profile row owned by `userID`. Both
    /// `displayName` and `bio` are nullable in the schema — pass `nil` to
    /// clear. RLS guarantees a user can only update their own row.
    func updateProfile(
        userID: UUID,
        displayName: String?,
        bio: String?
    ) async throws

    /// Aggregate counts for the profile tiles + library section. One
    /// query, aggregated client-side. Cheap until any user crosses
    /// ~10k posts — at that point this becomes a Postgres RPC with
    /// GROUP BY done server-side.
    func metrics(for userID: UUID) async throws -> ProfileMetrics
}

/// Production implementation backed by the Supabase Postgrest client.
///
/// All throwing methods funnel third-party errors through
/// `AppError.from(_:)` so callers see a single semantic error type.
/// See ADR 0006.
struct ProfileService: ProfileServicing {
    let client: SupabaseClient

    func profile(for userID: UUID) async throws -> UserProfile {
        do {
            return try await client
                .from("profiles")
                .select()
                .eq("id", value: userID)
                .single()
                .execute()
                .value
        } catch {
            throw AppError.from(error)
        }
    }

    func updateProfile(
        userID: UUID,
        displayName: String?,
        bio: String?
    ) async throws {
        let payload = ProfileUpdate(displayName: displayName, bio: bio)
        do {
            try await client
                .from("profiles")
                .update(payload)
                .eq("id", value: userID)
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func metrics(for userID: UUID) async throws -> ProfileMetrics {
        do {
            // `media!inner(kind)` forces an inner join so rows without
            // a matching media (shouldn't happen given the FK, but
            // defensive) drop out. We only pull `action` + `kind`
            // because that's all the aggregation needs.
            let rows: [ProfileMetricsRow] = try await client
                .from("posts")
                .select("action, media!inner(kind)")
                .eq("author_id", value: userID)
                .execute()
                .value
            return ProfileMetrics(rows: rows)
        } catch {
            throw AppError.from(error)
        }
    }
}

/// Wire-format payload for `updateProfile`. The custom `encode(to:)`
/// emits explicit JSON `null` for nil values — `JSONEncoder`'s default is
/// to omit absent optionals, but Postgrest needs the key present to
/// actually clear the column.
private struct ProfileUpdate: Encodable {
    let displayName: String?
    let bio: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case bio
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let displayName {
            try container.encode(displayName, forKey: .displayName)
        } else {
            try container.encodeNil(forKey: .displayName)
        }
        if let bio {
            try container.encode(bio, forKey: .bio)
        } else {
            try container.encodeNil(forKey: .bio)
        }
    }
}
