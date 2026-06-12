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

    /// Upload a JPEG avatar to Storage (`avatars/<uid>/avatar.jpg`,
    /// replacing any previous one), point `profiles.avatar_url` at it, and
    /// return the public URL. Storage policies scope writes to the caller's
    /// own folder.
    func uploadAvatar(userID: UUID, jpegData: Data) async throws -> URL
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

    func uploadAvatar(userID: UUID, jpegData: Data) async throws -> URL {
        do {
            // Lowercased to match the folder-scoped Storage policy —
            // auth.uid()::text renders lowercase.
            let path = "\(userID.uuidString.lowercased())/avatar.jpg"
            try await client.storage
                .from("avatars")
                .upload(
                    path,
                    data: jpegData,
                    options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true)
                )
            let publicURL = try client.storage.from("avatars").getPublicURL(path: path)
            // Cache-busting version param: the path is stable across
            // re-uploads, and URLCache/AsyncImage would happily keep
            // serving the old picture without it.
            var components = URLComponents(url: publicURL, resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "v", value: String(Int(Date().timeIntervalSince1970))),
            ]
            let url = components?.url ?? publicURL
            try await client
                .from("profiles")
                .update(["avatar_url": url.absoluteString])
                .eq("id", value: userID)
                .execute()
            return url
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

    func watchlist(for userID: UUID, kind: MediaKind?) async throws -> [LibraryItem] {
        try await libraryItems(for: userID, actions: [PostAction.saved.rawValue], kind: kind)
    }

    func collection(for userID: UUID, kind: MediaKind?) async throws -> [LibraryItem] {
        try await libraryItems(
            for: userID,
            actions: [PostAction.logged.rawValue, PostAction.rated.rawValue],
            kind: kind
        )
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

    /// Shared library query: the author's posts with the given actions,
    /// joined with media, newest first, optionally scoped to one kind.
    private func libraryItems(
        for userID: UUID,
        actions: [String],
        kind: MediaKind?
    ) async throws -> [LibraryItem] {
        do {
            let rows: [LibraryItemRow] = try await client
                .from("posts")
                .select(LibraryItemRow.selectClause)
                .eq("author_id", value: userID)
                .in("action", values: actions)
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
