import Foundation
import Testing
@testable import Venn

/// Matching fan-out. The write path is a single RPC call, covered by the
/// SQL harness in supabase/tests/import_library_test.sql.
struct ImportServiceTests {
    private static func entry(_ title: String, _ year: Int?) -> ImportEntry {
        ImportEntry(
            kind: .movie,
            title: title,
            year: year,
            creator: nil,
            isbn: nil,
            action: .logged,
            rating: nil,
            consumedAt: nil
        )
    }

    private static func film(_ id: String, _ title: String, _ year: Int) -> MediaCandidate {
        MediaCandidate(
            title: title,
            primaryCreator: nil,
            year: year,
            coverURL: nil,
            overview: nil,
            externalID: id,
            externalSource: .tmdb,
            kind: .movie
        )
    }

    @Test
    func returnsOneResultPerEntryInOrder() async {
        let catalog = ["Heat": [Self.film("1", "Heat", 1995)], "Arrival": [Self.film("2", "Arrival", 2016)]]
        let entries = [Self.entry("Arrival", 2016), Self.entry("Unknown", 2000), Self.entry("Heat", 1995)]
        let matches = await ImportService.matchAll(entries, concurrency: 2) { entry in
            ImportMatcher.bestMatch(title: entry.title, year: entry.year, candidates: catalog[entry.title] ?? [])
        }
        #expect(matches.map { $0?.externalID } == ["2", nil, "1"])
    }

    @Test
    func aFailedLookupIsUnmatchedWithoutFailingTheBatch() async {
        let entries = [Self.entry("Boom", 2000), Self.entry("Heat", 1995)]
        let matches = await ImportService.matchAll(entries, concurrency: 5) { entry in
            if entry.title == "Boom" {
                throw AppError.server
            }
            return Self.film("1", "Heat", 1995)
        }
        #expect(matches.map { $0?.externalID } == [nil, "1"])
    }

    @Test
    func searchingFilmsWithoutATMDBKeyIsAValidationError() async {
        let service = ImportService(tmdb: nil, client: SupabaseClientProvider.preview.client)
        await #expect(throws: AppError.self) {
            try await service.match([Self.entry("Heat", 1995)])
        }
    }

    // MARK: - Books

    private static let hungerGames = ImportEntry(
        kind: .book,
        title: "The Hunger Games (The Hunger Games, #1)",
        year: 2008,
        creator: "Suzanne Collins",
        isbn: "9780439023481",
        action: .rated,
        rating: 5,
        consumedAt: "2023-01-15"
    )

    private static func book(_ id: String, _ title: String) -> MediaCandidate {
        MediaCandidate(
            title: title,
            primaryCreator: "Suzanne Collins",
            year: 2008,
            coverURL: nil,
            overview: nil,
            externalID: id,
            externalSource: .openlibrary,
            kind: .book
        )
    }

    @Test
    func aBookTrustsAnISBNHit() async throws {
        let openLibrary = FakeOpenLibraryService()
        openLibrary.result = .success([Self.book("W9", "Hunger Games")])
        let match = try await ImportService.matchOne(Self.hungerGames, tmdb: nil, openLibrary: openLibrary)
        #expect(match?.externalID == "W9")
        #expect(openLibrary.lastQuery == "isbn:9780439023481")
    }

    @Test
    func aBookFallsBackToTitleAndAuthorWithoutTheSeries() async throws {
        let openLibrary = SequencedOpenLibrary(responses: [[], [Self.book("W7", "The Hunger Games")]])
        let match = try await ImportService.matchOne(Self.hungerGames, tmdb: nil, openLibrary: openLibrary)
        #expect(match?.externalID == "W7")
        #expect(openLibrary.queries == ["isbn:9780439023481", "The Hunger Games Suzanne Collins"])
    }

    @Test
    func booksAloneNeedNoTMDBKey() async throws {
        let service = ImportService(
            tmdb: nil,
            openLibrary: SequencedOpenLibrary(responses: [[Self.book("W9", "Hunger Games")]]),
            client: SupabaseClientProvider.preview.client
        )
        let matches = try await service.match([Self.hungerGames])
        #expect(matches.map { $0?.externalID } == ["W9"])
    }
}

/// Answers each search with the next canned response, recording queries.
final class SequencedOpenLibrary: OpenLibraryServicing, @unchecked Sendable {
    private var responses: [[MediaCandidate]]
    private(set) var queries: [String] = []

    init(responses: [[MediaCandidate]]) {
        self.responses = responses
    }

    func searchBooks(query: String, page _: Int) async throws -> [MediaCandidate] {
        queries.append(query)
        return responses.isEmpty ? [] : responses.removeFirst()
    }
}
