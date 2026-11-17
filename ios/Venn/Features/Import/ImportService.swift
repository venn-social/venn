import Foundation
import Supabase

/// The two network steps of an import, behind a protocol so
/// `LibraryImporter` can be unit-tested with a fake (ADR 0005).
protocol ImportServicing: Sendable {
    /// Catalog matches for a batch of entries, in the same order; nil = none.
    func match(_ entries: [ImportEntry]) async throws -> [MediaCandidate?]

    /// Writes one batch through `import_library`, which is idempotent:
    /// items already in the library are skipped, never overwritten.
    func write(_ items: [ImportItem]) async throws -> ImportWriteResult
}

/// Production implementation: TMDB for matching, Supabase for writing.
struct ImportService: ImportServicing {
    /// Catalog lookups in flight at once — polite to TMDB's per-second limit.
    private static let concurrency = 5

    private let tmdb: (any TMDBServicing)?
    private let client: SupabaseClient

    /// `tmdb` should answer in English: Letterboxd exports carry English or
    /// original titles, and matching compares titles, so a translated
    /// catalog would turn exact matches into misses.
    init(tmdb: (any TMDBServicing)?, client: SupabaseClient) {
        self.tmdb = tmdb
        self.client = client
    }

    func match(_ entries: [ImportEntry]) async throws -> [MediaCandidate?] {
        guard let tmdb else {
            throw AppError.validation("Importing films requires a TMDB API key — add TMDB_API_KEY to .env.")
        }
        return await Self.matchAll(entries, concurrency: Self.concurrency) { entry in
            try await Self.search(entry, tmdb: tmdb)
        }
    }

    func write(_ items: [ImportItem]) async throws -> ImportWriteResult {
        do {
            return try await client
                .rpc("import_library", params: ImportLibraryParams(items: items))
                .execute()
                .value
        } catch {
            throw AppError.from(error)
        }
    }

    private static func search(_ entry: ImportEntry, tmdb: any TMDBServicing) async throws -> [MediaCandidate] {
        switch entry.kind {
        case .movie:
            try await tmdb.searchMovies(query: entry.title, page: 1)
        case .show:
            try await tmdb.searchShows(query: entry.title, page: 1)
        case .book, .album:
            []
        }
    }

    /// One lookup per entry, `concurrency` at a time, then
    /// `ImportMatcher.bestMatch`. A failed lookup for one entry counts as
    /// unmatched rather than failing the batch — one odd title should not
    /// sink a 500-film import. Internal so tests can drive it directly.
    static func matchAll(
        _ entries: [ImportEntry],
        concurrency: Int,
        lookup: @escaping @Sendable (ImportEntry) async throws -> [MediaCandidate]
    ) async -> [MediaCandidate?] {
        var results = [MediaCandidate?](repeating: nil, count: entries.count)
        for start in stride(from: 0, to: entries.count, by: max(concurrency, 1)) {
            let end = min(start + max(concurrency, 1), entries.count)
            await withTaskGroup(of: (Int, MediaCandidate?).self) { group in
                for index in start..<end {
                    let entry = entries[index]
                    group.addTask {
                        let candidates = await (try? lookup(entry)) ?? []
                        return (
                            index,
                            ImportMatcher.bestMatch(title: entry.title, year: entry.year, candidates: candidates)
                        )
                    }
                }
                while let finished = await group.next() {
                    results[finished.0] = finished.1
                }
            }
        }
        return results
    }
}

private struct ImportLibraryParams: Encodable {
    let items: [ImportItem]

    enum CodingKeys: String, CodingKey {
        case items = "_items"
    }
}
