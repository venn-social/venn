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

    /// Items the user saved for later (`action == .saved`). Pass a `kind`
    /// to scope the results to one media type; nil returns all kinds.
    func watchlist(for userID: UUID, kind: MediaKind?) async throws -> [LibraryItem]

    /// Items the user has consumed (`action IN ('logged','rated')`). Pass a
    /// `kind` to scope; nil returns all kinds.
    func collection(for userID: UUID, kind: MediaKind?) async throws -> [LibraryItem]

    /// Delete a single post row (the user's own). RLS prevents deleting
    /// other users' posts server-side; the app only surfaces this action on
    /// the signed-in user's own library.
    func removeFromLibrary(postID: UUID) async throws
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

    func watchlist(for userID: UUID, kind: MediaKind?) async throws -> [LibraryItem] {
        do {
            let rows: [LibraryItemRow] = try await client
                .from("posts")
                .select(LibraryItemRow.selectClause)
                .eq("author_id", value: userID)
                .eq("action", value: PostAction.saved.rawValue)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
                .compactMap(LibraryItem.init(row:))
                .filter { kind == nil || $0.media.kind == kind }
        } catch {
            throw AppError.from(error)
        }
    }

    func collection(for userID: UUID, kind: MediaKind?) async throws -> [LibraryItem] {
        do {
            let rows: [LibraryItemRow] = try await client
                .from("posts")
                .select(LibraryItemRow.selectClause)
                .eq("author_id", value: userID)
                .in("action", values: [PostAction.logged.rawValue, PostAction.rated.rawValue])
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows
                .compactMap(LibraryItem.init(row:))
                .filter { kind == nil || $0.media.kind == kind }
        } catch {
            throw AppError.from(error)
        }
    }

    func removeFromLibrary(postID: UUID) async throws {
        do {
            try await client
                .from("posts")
                .delete()
                .eq("id", value: postID)
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }
}

/// Wire-format row for the `watchlist` / `collection` queries. The PostgREST
/// `!inner` join embeds the matching `media` row as a nested object.
private struct LibraryItemRow: Decodable {
    let id: UUID
    let authorId: UUID
    let mediaId: UUID
    let action: String
    let rating: Double?
    let caption: String?
    let createdAt: Date
    let media: MediaSchema.Row

    enum CodingKeys: String, CodingKey {
        case id, action, rating, caption, media
        case authorId = "author_id"
        case mediaId = "media_id"
        case createdAt = "created_at"
    }

    static let selectClause =
        "id, author_id, media_id, action, rating, caption, created_at, " +
        "media!inner(id, kind, title, year, primary_creator, cover_url, external_id, external_source, created_at)"
}

private extension LibraryItem {
    init?(row: LibraryItemRow) {
        guard let action = PostAction(rawValue: row.action),
              let media = Media(row: row.media)
        else { return nil }
        post = Post(
            id: row.id,
            authorID: row.authorId,
            mediaID: row.mediaId,
            action: action,
            rating: row.rating,
            caption: row.caption,
            createdAt: row.createdAt
        )
        self.media = media
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
