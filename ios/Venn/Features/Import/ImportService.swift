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

/// Production implementation: TMDB and Open Library for matching, Supabase
/// for writing.
struct ImportService: ImportServicing {
    private let tmdb: (any TMDBServicing)?
    private let openLibrary: any OpenLibraryServicing
    private let client: SupabaseClient

    /// `tmdb` should answer in English: Letterboxd exports carry English or
    /// original titles, and matching compares titles, so a translated
    /// catalog would turn exact matches into misses.
    init(
        tmdb: (any TMDBServicing)?,
        openLibrary: any OpenLibraryServicing = OpenLibraryService(),
        client: SupabaseClient
    ) {
        self.tmdb = tmdb
        self.openLibrary = openLibrary
        self.client = client
    }

    func match(_ entries: [ImportEntry]) async throws -> [MediaCandidate?] {
        let needsTMDB = entries.contains { $0.kind == .movie || $0.kind == .show }
        if needsTMDB, tmdb == nil {
            throw AppError.validation("Importing films requires a TMDB API key — add TMDB_API_KEY to .env.")
        }
        let tmdb = tmdb
        let openLibrary = openLibrary
        return await Self.matchAll(entries, concurrency: Self.concurrency(for: entries)) { entry in
            try await Self.matchOne(entry, tmdb: tmdb, openLibrary: openLibrary)
        }
    }

    /// Catalog lookups in flight at once. TMDB allows dozens a second; Open
    /// Library throttles hard and answers a burst with an empty 200, which
    /// would read as "no match", so books go two at a time.
    static func concurrency(for entries: [ImportEntry]) -> Int {
        entries.contains { $0.kind == .book || $0.kind == .album } ? 2 : 5
    }

    /// Books try the ISBN first: an ISBN hit is the book, whatever its title
    /// says in that edition. Without one — or when Open Library does not
    /// know it — they fall back to title and author. Internal for tests.
    static func matchOne(
        _ entry: ImportEntry,
        tmdb: (any TMDBServicing)?,
        openLibrary: any OpenLibraryServicing
    ) async throws -> MediaCandidate? {
        switch entry.kind {
        case .movie, .show:
            guard let tmdb else { return nil }
            let results: [MediaCandidate] = if entry.kind == .movie {
                try await tmdb.searchMovies(query: entry.title, page: 1)
            } else {
                try await tmdb.searchShows(query: entry.title, page: 1)
            }
            return ImportMatcher.bestMatch(title: entry.title, year: entry.year, candidates: results)
        case .book:
            if let isbn = entry.isbn {
                let hits = try await openLibrary.searchBooks(query: "isbn:\(isbn)", page: 1)
                if let hit = hits.first {
                    return hit
                }
            }
            // The series suffix is Goodreads' own and only adds noise to the search.
            let title = ImportMatcher.withoutSeries(entry.title)
            let query = entry.creator.map { "\(title) \($0)" } ?? title
            let results = try await openLibrary.searchBooks(query: query, page: 1)
            return ImportMatcher.bestBookMatch(title: entry.title, author: entry.creator, candidates: results)
        case .album:
            return nil
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

    /// One match per entry, `concurrency` at a time. A failed lookup for one
    /// entry counts as unmatched rather than failing the batch — one odd
    /// title should not sink a 500-film import. Internal for tests.
    static func matchAll(
        _ entries: [ImportEntry],
        concurrency: Int,
        match: @escaping @Sendable (ImportEntry) async throws -> MediaCandidate?
    ) async -> [MediaCandidate?] {
        var results = [MediaCandidate?](repeating: nil, count: entries.count)
        for start in stride(from: 0, to: entries.count, by: max(concurrency, 1)) {
            let end = min(start + max(concurrency, 1), entries.count)
            await withTaskGroup(of: (Int, MediaCandidate?).self) { group in
                for index in start..<end {
                    let entry = entries[index]
                    group.addTask {
                        let found = try? await match(entry)
                        return (index, found)
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
