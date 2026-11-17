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
            catalog[entry.title] ?? []
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
            return [Self.film("1", "Heat", 1995)]
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
}
