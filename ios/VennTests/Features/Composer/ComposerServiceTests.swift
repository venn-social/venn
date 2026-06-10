import Foundation
import Testing
@testable import Venn

/// Tests for ComposerService search routing and MediaInsertPayload encoding.
/// No Supabase calls — the `log` path is integration-tested separately.
@MainActor
struct ComposerServiceTests {
    // MARK: - Search routing

    @Test
    func searchMoviesRoutesToTMDB() async throws {
        let tmdb = FakeTMDBService()
        let expected = [makeCandidate(kind: .movie)]
        tmdb.moviesResult = .success(expected)

        let service = makeService(tmdb: tmdb)
        let results = try await service.search(query: "The Godfather", kind: .movie)

        #expect(results == expected)
        #expect(tmdb.lastMoviesQuery == "The Godfather")
        #expect(tmdb.lastShowsQuery == nil)
    }

    @Test
    func searchShowsRoutesToTMDB() async throws {
        let tmdb = FakeTMDBService()
        let expected = [makeCandidate(kind: .show)]
        tmdb.showsResult = .success(expected)

        let service = makeService(tmdb: tmdb)
        let results = try await service.search(query: "Breaking Bad", kind: .show)

        #expect(results == expected)
        #expect(tmdb.lastShowsQuery == "Breaking Bad")
        #expect(tmdb.lastMoviesQuery == nil)
    }

    @Test
    func searchBooksRoutesToOpenLibrary() async throws {
        let ol = FakeOpenLibraryService()
        let expected = [makeCandidate(kind: .book)]
        ol.result = .success(expected)

        let service = makeService(openLibrary: ol)
        let results = try await service.search(query: "Hamlet", kind: .book)

        #expect(results == expected)
        #expect(ol.lastQuery == "Hamlet")
    }

    @Test
    func searchAlbumsRoutesToMusicBrainz() async throws {
        let mb = FakeMusicBrainzService()
        let expected = [makeCandidate(kind: .album)]
        mb.result = .success(expected)

        let service = makeService(musicBrainz: mb)
        let results = try await service.search(query: "OK Computer", kind: .album)

        #expect(results == expected)
        #expect(mb.lastQuery == "OK Computer")
    }

    @Test
    func searchMoviesWithoutTMDBKeyThrowsValidation() async {
        let service = makeService(tmdb: nil)
        await #expect(throws: AppError.self) {
            _ = try await service.search(query: "anything", kind: .movie)
        }
    }

    @Test
    func searchShowsWithoutTMDBKeyThrowsValidation() async {
        let service = makeService(tmdb: nil)
        await #expect(throws: AppError.self) {
            _ = try await service.search(query: "anything", kind: .show)
        }
    }

    // MARK: - MediaInsertPayload encoding

    @Test
    func mediaInsertPayloadEncodesAllFields() throws {
        let candidate = MediaCandidate(
            title: "Past Lives",
            primaryCreator: "Celine Song",
            year: 2023,
            coverURL: URL(string: "https://image.tmdb.org/t/p/w500/poster.jpg"),
            overview: nil,
            externalID: "976573",
            externalSource: .tmdb,
            kind: .movie
        )
        let payload = MediaInsertPayload(candidate)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["kind"] as? String == "movie")
        #expect(json?["title"] as? String == "Past Lives")
        #expect(json?["year"] as? Int == 2023)
        #expect(json?["primary_creator"] as? String == "Celine Song")
        #expect(json?["external_id"] as? String == "976573")
        #expect(json?["external_source"] as? String == "tmdb")
        #expect((json?["cover_url"] as? String)?.contains("poster.jpg") == true)
    }

    @Test
    func mediaInsertPayloadOmitsNilOptionals() throws {
        let candidate = MediaCandidate(
            title: "Untitled",
            primaryCreator: nil,
            year: nil,
            coverURL: nil,
            overview: nil,
            externalID: "OL99W",
            externalSource: .openlibrary,
            kind: .book
        )
        let payload = MediaInsertPayload(candidate)
        let data = try JSONEncoder().encode(payload)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        #expect(json?["year"] == nil)
        #expect(json?["primary_creator"] == nil)
        #expect(json?["cover_url"] == nil)
    }

    // MARK: - Helpers

    private func makeService(
        tmdb: (any TMDBServicing)? = FakeTMDBService(),
        openLibrary: any OpenLibraryServicing = FakeOpenLibraryService(),
        musicBrainz: any MusicBrainzServicing = FakeMusicBrainzService()
    ) -> ComposerService {
        ComposerService(
            tmdb: tmdb,
            openLibrary: openLibrary,
            musicBrainz: musicBrainz,
            client: SupabaseClientProvider.preview.client
        )
    }

    private func makeCandidate(kind: MediaKind) -> MediaCandidate {
        MediaCandidate(
            title: "Test \(kind.rawValue)",
            primaryCreator: nil,
            year: 2024,
            coverURL: nil,
            overview: nil,
            externalID: "ext-\(kind.rawValue)",
            externalSource: kind == .album ? .musicbrainz : (kind == .book ? .openlibrary : .tmdb),
            kind: kind
        )
    }
}

// MARK: - Fakes

final class FakeTMDBService: TMDBServicing, @unchecked Sendable {
    var moviesResult: Result<[MediaCandidate], Error> = .success([])
    var showsResult: Result<[MediaCandidate], Error> = .success([])
    private(set) var lastMoviesQuery: String?
    private(set) var lastShowsQuery: String?

    func searchMovies(query: String, page _: Int) async throws -> [MediaCandidate] {
        lastMoviesQuery = query
        return try moviesResult.get()
    }

    func searchShows(query: String, page _: Int) async throws -> [MediaCandidate] {
        lastShowsQuery = query
        return try showsResult.get()
    }
}

final class FakeOpenLibraryService: OpenLibraryServicing, @unchecked Sendable {
    var result: Result<[MediaCandidate], Error> = .success([])
    private(set) var lastQuery: String?

    func searchBooks(query: String, page _: Int) async throws -> [MediaCandidate] {
        lastQuery = query
        return try result.get()
    }
}

final class FakeMusicBrainzService: MusicBrainzServicing, @unchecked Sendable {
    var result: Result<[MediaCandidate], Error> = .success([])
    private(set) var lastQuery: String?

    func searchAlbums(query: String, page _: Int) async throws -> [MediaCandidate] {
        lastQuery = query
        return try result.get()
    }
}
