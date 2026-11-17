import Foundation
import Testing
@testable import Venn

/// Mirrors web's `lib/import/__tests__/importer.test.ts`.
struct LibraryImporterTests {
    @Test
    func writesMatchesReportsUnmatchedAndPassesProblemsThrough() async throws {
        let service = FakeImportService { batch in batch.map { $0.title == "Nope" ? nil : candidate($0.title) } }
        let problems = [ImportRowProblem(file: "watched.csv", line: 4, reason: .missingTitle)]
        let report = try await LibraryImporter(service: service)
            .run(ParsedExport(entries: [entry("A"), entry("Nope"), entry("B")], problems: problems))

        #expect(report == ImportReport(
            imported: 2,
            alreadyInLibrary: 0,
            unmatched: [entry("Nope")],
            problems: problems
        ))
    }

    @Test
    func isIdempotent() async throws {
        let service = FakeImportService { batch in batch.map { candidate($0.title) } }
        let importer = LibraryImporter(service: service)
        let parsed = ParsedExport(entries: [entry("A"), entry("B")], problems: [])
        _ = try await importer.run(parsed)
        let second = try await importer.run(parsed)

        #expect(second.imported == 0)
        #expect(second.alreadyInLibrary == 2)
        #expect(service.libraryCount == 2)
    }

    @Test
    func collapsesRowsMatchingTheSameItemKeepingTheMostInformative() async throws {
        let service = FakeImportService { batch in batch.map { _ in candidate("same") } }
        let report = try await LibraryImporter(service: service).run(ParsedExport(
            entries: [entry("X", action: .saved), entry("X again", action: .rated, rating: 5)],
            problems: []
        ))

        #expect(service.writes.count == 1)
        #expect(service.writes.first?.map(\.action) == ["rated"])
        #expect(report.imported == 1)
        #expect(report.alreadyInLibrary == 1)
    }

    @Test
    func batchesWithinTheServersLimits() async throws {
        let service = FakeImportService { batch in batch.map { candidate($0.title) } }
        let entries = (0..<450).map { entry(String($0)) }
        let report = try await LibraryImporter(service: service).run(ParsedExport(entries: entries, problems: []))

        #expect(service.matchBatchSizes.count == Int((450.0 / Double(LibraryImporter.matchBatch)).rounded(.up)))
        #expect(service.matchBatchSizes.allSatisfy { $0 <= LibraryImporter.matchBatch })
        #expect(service.writes.count == 3)
        #expect(service.writes.allSatisfy { $0.count <= LibraryImporter.writeBatch })
        #expect(report.imported == 450)
    }

    @Test
    func writesNothingWhenMatchingFailsPartWay() async {
        let service = FakeImportService(failOnMatchCall: 2) { batch in batch.map { candidate($0.title) } }
        let entries = (0...LibraryImporter.matchBatch).map { entry(String($0)) }
        await #expect(throws: AppError.network) {
            try await LibraryImporter(service: service).run(ParsedExport(entries: entries, problems: []))
        }
        #expect(service.writes.isEmpty)
    }

    @Test
    func importItemTakesCatalogFieldsFromTheMatchAndTheOpinionFromTheExport() throws {
        let item = ImportItem(entry: entry("ignored", action: .rated, rating: 3), candidate: candidate("9"))
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any]

        #expect(json?["title"] as? String == "Film 9")
        #expect(json?["external_source"] as? String == "tmdb")
        #expect(json?["external_id"] as? String == "9")
        #expect(json?["action"] as? String == "rated")
        #expect(json?["rating"] as? Double == 3)
        #expect(json?["consumed_at"] as? String == "2020-01-01")
        // Nil fields are sent as null, not dropped: the RPC reads every key.
        #expect(json?["primary_creator"] is NSNull)
        #expect(json?.keys.count == 10)
    }
}

// MARK: - Helpers

private func entry(
    _ title: String,
    action: PostAction = .logged,
    rating: Double? = nil
) -> ImportEntry {
    ImportEntry(
        kind: .movie,
        title: title,
        year: 2000,
        creator: nil,
        isbn: nil,
        action: action,
        rating: rating,
        consumedAt: "2020-01-01"
    )
}

private func candidate(_ id: String) -> MediaCandidate {
    MediaCandidate(
        title: "Film \(id)",
        primaryCreator: nil,
        year: 2000,
        coverURL: nil,
        overview: nil,
        externalID: id,
        externalSource: .tmdb,
        kind: .movie
    )
}

/// A fake with `import_library`'s semantics: one row per external id,
/// re-imports skipped.
final class FakeImportService: ImportServicing, @unchecked Sendable {
    private let matcher: ([ImportEntry]) -> [MediaCandidate?]
    private let failOnMatchCall: Int?
    private var library: Set<String> = []
    private(set) var writes: [[ImportItem]] = []
    private(set) var matchBatchSizes: [Int] = []

    var libraryCount: Int {
        library.count
    }

    init(failOnMatchCall: Int? = nil, matcher: @escaping ([ImportEntry]) -> [MediaCandidate?]) {
        self.failOnMatchCall = failOnMatchCall
        self.matcher = matcher
    }

    func match(_ entries: [ImportEntry]) async throws -> [MediaCandidate?] {
        matchBatchSizes.append(entries.count)
        if matchBatchSizes.count == failOnMatchCall {
            throw AppError.network
        }
        return matcher(entries)
    }

    func write(_ items: [ImportItem]) async throws -> ImportWriteResult {
        writes.append(items)
        var imported = 0
        for item in items where !library.contains(item.externalId) {
            library.insert(item.externalId)
            imported += 1
        }
        return ImportWriteResult(imported: imported, skipped: items.count - imported)
    }
}
