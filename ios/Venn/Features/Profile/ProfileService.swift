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

    /// Follower / following counts from the `follows` table.
    func followCounts(for userID: UUID) async throws -> FollowCounts

    /// The distinct media on a profile shelf (Collection or Watchlist),
    /// newest first, capped at `limit`. Covers-only gallery.
    func shelf(_ shelf: ProfileShelf, for userID: UUID, limit: Int) async throws -> [Media]
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

    func followCounts(for userID: UUID) async throws -> FollowCounts {
        do {
            async let followers = edgeCount(column: "followee_id", value: userID)
            async let following = edgeCount(column: "follower_id", value: userID)
            return try await FollowCounts(followers: followers, following: following)
        } catch {
            throw AppError.from(error)
        }
    }

    func shelf(_ shelf: ProfileShelf, for userID: UUID, limit: Int) async throws -> [Media] {
        do {
            let rows: [ShelfMediaRow] = try await client
                .from("posts")
                .select("created_at, media!inner(*)")
                .eq("author_id", value: userID)
                .in("action", values: shelf.actions)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            // De-dup by media id (logging *and* rating the same title yields
            // two rows) while preserving newest-first order.
            var seen = Set<UUID>()
            return rows.compactMap { row in
                guard let media = Media(row: row.media),
                      seen.insert(media.id).inserted
                else {
                    return nil
                }
                return media
            }
        } catch {
            throw AppError.from(error)
        }
    }

    /// Head-only count of `follows` rows matching `column == value`.
    private func edgeCount(column: String, value: UUID) async throws -> Int {
        try await client
            .from("follows")
            .select("*", head: true, count: .exact)
            .eq(column, value: value)
            .execute()
            .count ?? 0
    }
}

/// Wire-format row for a shelf query — only the embedded media is selected,
/// since the gallery renders covers only.
private struct ShelfMediaRow: Decodable {
    let media: MediaSchema.Row
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
