import Foundation
import Supabase

/// End-to-end logging surface. The post composer calls this:
///   1. `search` — queries the right external catalog (TMDB / OpenLibrary /
///      MusicBrainz) and returns ranked results for the user to pick from.
///   2. `log` — once the user confirms, upserts the chosen item into
///      `public.media` (idempotent) and inserts a `public.posts` row.
///
/// Behind a protocol so `ComposerViewModel` can be unit-tested with a fake
/// (ADR 0005) without hitting any network or Supabase.
protocol ComposerServicing: Sendable {
    /// Search an external catalog for `query` narrowed to `kind`. Page is
    /// 1-based; each page returns up to 20 results.
    func search(query: String, kind: MediaKind, page: Int) async throws -> [MediaCandidate]

    /// Upsert the chosen `candidate` into `public.media` (select-then-insert,
    /// idempotent on `external_source + external_id`), then insert a post row.
    func log(
        candidate: MediaCandidate,
        authorID: UUID,
        action: PostAction,
        rating: Double?,
        caption: String?
    ) async throws -> Post
}

/// Production implementation. Holds the three external search services and
/// the Supabase client.
struct ComposerService: ComposerServicing {
    private let tmdb: (any TMDBServicing)?
    private let openLibrary: any OpenLibraryServicing
    private let musicBrainz: any MusicBrainzServicing
    private let client: SupabaseClient

    /// `tmdb` is optional — if nil, searching `.movie` or `.show` throws
    /// `AppError.validation` with a helpful message rather than crashing.
    /// `openLibrary` and `musicBrainz` default to their production
    /// implementations since they need no API key.
    init(
        tmdb: (any TMDBServicing)?,
        openLibrary: any OpenLibraryServicing = OpenLibraryService(),
        musicBrainz: any MusicBrainzServicing = MusicBrainzService(),
        client: SupabaseClient
    ) {
        self.tmdb = tmdb
        self.openLibrary = openLibrary
        self.musicBrainz = musicBrainz
        self.client = client
    }

    func search(query: String, kind: MediaKind, page: Int = 1) async throws -> [MediaCandidate] {
        do {
            switch kind {
            case .movie:
                guard let tmdb else {
                    throw AppError.validation("Movie search requires a TMDB API key — add TMDB_API_KEY to .env.")
                }
                return try await tmdb.searchMovies(query: query, page: page)
            case .show:
                guard let tmdb else {
                    throw AppError.validation("Show search requires a TMDB API key — add TMDB_API_KEY to .env.")
                }
                return try await tmdb.searchShows(query: query, page: page)
            case .book:
                return try await openLibrary.searchBooks(query: query, page: page)
            case .album:
                return try await musicBrainz.searchAlbums(query: query, page: page)
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.from(error)
        }
    }

    func log(
        candidate: MediaCandidate,
        authorID: UUID,
        action: PostAction,
        rating: Double?,
        caption: String?
    ) async throws -> Post {
        do {
            let mediaID = try await upsertMedia(candidate)
            return try await insertPost(
                authorID: authorID,
                mediaID: mediaID,
                action: action,
                rating: rating,
                caption: caption
            )
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.from(error)
        }
    }

    // MARK: - Private helpers

    /// Returns the UUID of the existing or newly-inserted media row.
    ///
    /// PostgREST cannot target the partial unique index
    /// `media_external_unique` directly, so we use a select-then-insert
    /// pattern. A concurrent insert of the same (source, id) pair will be
    /// caught by the DB constraint; the calling code treats that as success.
    private func upsertMedia(_ candidate: MediaCandidate) async throws -> UUID {
        let existing: [MediaIDRow] = try await client
            .from("media")
            .select("id")
            .eq("external_source", value: candidate.externalSource.rawValue)
            .eq("external_id", value: candidate.externalID)
            .limit(1)
            .execute()
            .value
        if let row = existing.first { return row.id }

        let inserted: [MediaIDRow] = try await client
            .from("media")
            .insert(MediaInsertPayload(candidate))
            .select("id")
            .execute()
            .value
        guard let row = inserted.first else {
            throw AppError.unknown(message: "Media insert returned no id")
        }
        return row.id
    }

    private func insertPost(
        authorID: UUID,
        mediaID: UUID,
        action: PostAction,
        rating: Double?,
        caption: String?
    ) async throws -> Post {
        let rows: [PostsSchema.Row] = try await client
            .from("posts")
            .insert(PostInsertPayload(
                authorID: authorID,
                mediaID: mediaID,
                action: action,
                rating: rating,
                caption: caption
            ))
            .select()
            .execute()
            .value
        guard let row = rows.first, let post = Post(row: row) else {
            throw AppError.unknown(message: "Post insert failed to decode")
        }
        return post
    }
}

// MARK: - Wire payloads (internal so ComposerServiceTests can encode-check them)

struct MediaInsertPayload: Encodable {
    let kind: String
    let title: String
    let year: Int?
    let primaryCreator: String?
    let coverUrl: String?
    let externalId: String
    let externalSource: String

    enum CodingKeys: String, CodingKey {
        case kind, title, year
        case primaryCreator = "primary_creator"
        case coverUrl = "cover_url"
        case externalId = "external_id"
        case externalSource = "external_source"
    }

    init(_ candidate: MediaCandidate) {
        kind = candidate.kind.rawValue
        title = candidate.title
        year = candidate.year
        primaryCreator = candidate.primaryCreator
        coverUrl = candidate.coverURL?.absoluteString
        externalId = candidate.externalID
        externalSource = candidate.externalSource.rawValue
    }
}

private struct MediaIDRow: Decodable {
    let id: UUID
}

private struct PostInsertPayload: Encodable {
    let authorId: UUID
    let mediaId: UUID
    let action: String
    let rating: Double?
    let caption: String?

    enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case mediaId = "media_id"
        case action, rating, caption
    }

    init(authorID: UUID, mediaID: UUID, action: PostAction, rating: Double?, caption: String?) {
        authorId = authorID
        mediaId = mediaID
        self.action = action.rawValue
        self.rating = rating
        self.caption = caption
    }
}
