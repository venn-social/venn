import Foundation

/// Runs a parsed export through matching and writing. Mirrors web's
/// `runImport` in `lib/import/importer.ts`.
///
/// Matching runs to completion before anything is written, so a failure
/// part-way through matching leaves the library untouched. Writing is
/// batched and idempotent on the server, so if a write fails part-way the
/// whole import can simply be run again: what was written is skipped.
struct LibraryImporter {
    /// Entries per match call; bounded so one call stays fast.
    static let matchBatch = 25
    /// Items per `import_library` call — the RPC refuses more than 200.
    static let writeBatch = 200

    let service: any ImportServicing

    func run(
        _ parsed: ParsedExport,
        onProgress: (@Sendable (_ done: Int, _ total: Int) -> Void)? = nil
    ) async throws -> ImportReport {
        let (matched, unmatched) = try await matchAll(parsed.entries, onProgress: onProgress)
        let items = Self.dedupe(matched).map { ImportItem(entry: $0.entry, candidate: $0.candidate) }

        var imported = 0
        var alreadyInLibrary = 0
        for start in stride(from: 0, to: items.count, by: Self.writeBatch) {
            let batch = Array(items[start..<min(start + Self.writeBatch, items.count)])
            let result = try await service.write(batch)
            imported += result.imported
            alreadyInLibrary += result.skipped
        }
        // Two export rows that matched the same catalog item collapse into
        // one write; count the extras as already there, so the totals add up.
        alreadyInLibrary += matched.count - items.count

        return ImportReport(
            imported: imported,
            alreadyInLibrary: alreadyInLibrary,
            unmatched: unmatched,
            problems: parsed.problems
        )
    }

    private func matchAll(
        _ entries: [ImportEntry],
        onProgress: (@Sendable (Int, Int) -> Void)?
    ) async throws -> (matched: [Matched], unmatched: [ImportEntry]) {
        var matched: [Matched] = []
        var unmatched: [ImportEntry] = []
        for start in stride(from: 0, to: entries.count, by: Self.matchBatch) {
            let batch = Array(entries[start..<min(start + Self.matchBatch, entries.count)])
            let results = try await service.match(batch)
            for (index, entry) in batch.enumerated() {
                if index < results.count, let candidate = results[index] {
                    matched.append(Matched(entry: entry, candidate: candidate))
                } else {
                    unmatched.append(entry)
                }
            }
            onProgress?(min(start + Self.matchBatch, entries.count), entries.count)
        }
        return (matched, unmatched)
    }

    struct Matched: Equatable {
        let entry: ImportEntry
        let candidate: MediaCandidate
    }

    /// Keeps the most informative entry per catalog item — rated over logged
    /// over saved — matching how the server collapses one item to one post.
    static func dedupe(_ matched: [Matched]) -> [Matched] {
        func rank(_ action: PostAction) -> Int {
            switch action {
            case .rated: 0
            case .logged: 1
            case .saved: 2
            }
        }
        var order: [String] = []
        var byItem: [String: Matched] = [:]
        for item in matched {
            let key = item.candidate.id
            if let existing = byItem[key] {
                if rank(item.entry.action) < rank(existing.entry.action) {
                    byItem[key] = item
                }
            } else {
                byItem[key] = item
                order.append(key)
            }
        }
        return order.compactMap { byItem[$0] }
    }
}
