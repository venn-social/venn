import Foundation

/// OpenLibrary (openlibrary.org) search for books. No API key required.
///
/// Uses the Open Library Search API: https://openlibrary.org/dev/docs/api#anchor_searchapi
protocol OpenLibraryServicing: Sendable {
    func searchBooks(query: String, page: Int) async throws -> [MediaCandidate]
}

/// Production implementation backed by the Open Library Search API.
///
/// Returns up to 20 results per page. Cover images come from the Open
/// Library Covers API; candidates with no `cover_i` have a nil coverURL.
struct OpenLibraryService: OpenLibraryServicing {
    private static let base = URL(staticString: "https://openlibrary.org")
    private static let coversBase = URL(staticString: "https://covers.openlibrary.org/b/id")
    private static let pageSize = 20
    /// A page of twenty foreign-language results should not become twenty
    /// extra requests; Open Library rate-limits hard and answers with an
    /// empty 200 when it does.
    private static let authorLookupLimit = 5

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchBooks(query: String, page: Int = 1) async throws -> [MediaCandidate] {
        let url = Self.searchURL(query: query, page: page)
        let data = try await ExternalAPI.fetch(url: url, session: session)
        let response = try JSONDecoder().decode(OLSearchResponse.self, from: data)
        return await withLatinAuthors(response.docs.map { ($0, Self.candidate(from: $0)) })
    }

    /// Replace author names written in another script with their Latin form.
    ///
    /// The search response only carries the name as printed on the book, so
    /// a Japanese author arrives as 村上春樹. The Latin form lives on the
    /// author record, which costs one request — but only for the credits
    /// that actually need it, which is nearly always none. Capped so a page
    /// of foreign-language results cannot fan out into twenty requests.
    ///
    /// This runs at search time on purpose: `primary_creator` is copied
    /// into `media` when something is logged, so fixing it only on the
    /// detail screen would leave every shelf and feed row still unreadable.
    private func withLatinAuthors(
        _ pairs: [(doc: OLDoc, candidate: MediaCandidate)]
    ) async -> [MediaCandidate] {
        let needing = pairs.filter { pair in
            guard let creator = pair.candidate.primaryCreator else { return false }
            return !AuthorName.isLatinScript(creator)
        }
        guard !needing.isEmpty else { return pairs.map(\.candidate) }

        var resolved: [String: String] = [:]
        for pair in needing.prefix(Self.authorLookupLimit) {
            guard let key = pair.doc.authorKey?.first, resolved[key] == nil else { continue }
            if let latin = await Self.latinAuthorName(key: key, session: session) {
                resolved[key] = latin
            }
        }
        guard !resolved.isEmpty else { return pairs.map(\.candidate) }

        return pairs.map { pair in
            guard let key = pair.doc.authorKey?.first, let latin = resolved[key] else {
                return pair.candidate
            }
            return pair.candidate.replacingPrimaryCreator(latin)
        }
    }

    /// One author record, for its Latin `personal_name`. Returns nil rather
    /// than throwing: a failed lookup should leave the original name, not
    /// fail the search.
    private static func latinAuthorName(key: String, session: URLSession) async -> String? {
        guard let url = URL(string: "https://openlibrary.org/authors/\(key).json") else {
            return nil
        }
        guard let data = try? await ExternalAPI.fetch(url: url, session: session),
              let record = try? JSONDecoder().decode(OLAuthorRecord.self, from: data)
        else {
            return nil
        }
        let preferred = AuthorName.preferred(name: record.name, personalName: record.personalName)
        guard let preferred, AuthorName.isLatinScript(preferred) else { return nil }
        return preferred
    }

    // MARK: - Helpers (internal for tests)

    static func candidate(from doc: OLDoc) -> MediaCandidate {
        // -L (465x475), not -M (180x183). A medium cover is smaller than the
        // tile it renders into, so every book was being upscaled — which is
        // what made the shelves look soft next to TMDB's posters. Open
        // Library serves -L via a 302, which URLSession follows.
        let shown = doc.presentation
        let coverURL = shown.coverID.map {
            coversBase.appending(path: "\($0)-L.jpg")
        }
        return MediaCandidate(
            title: shown.title,
            primaryCreator: doc.authorName?.first,
            year: doc.firstPublishYear,
            coverURL: coverURL,
            overview: doc.firstSentence?.value,
            externalID: workKey(from: doc.key),
            externalSource: .openlibrary,
            kind: .book
        )
    }

    /// Strips the "/works/" prefix so external_id is just "OL12345W".
    static func workKey(from fullKey: String) -> String {
        fullKey.hasPrefix("/works/") ? String(fullKey.dropFirst(7)) : fullKey
    }

    private static func searchURL(query: String, page: Int) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = "/search.json"
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(pageSize)),
            URLQueryItem(name: "page", value: String(page)),
            // Makes the response carry the edition that matched the query,
            // rather than only the work's original-language title.
            URLQueryItem(name: "fields", value: "*,editions"),
        ]
        guard let url = components?.url else {
            preconditionFailure("Invalid OpenLibrary search URL")
        }
        return url
    }
}

// MARK: - Wire format (internal for @testable import in tests)

struct OLDoc: Decodable {
    let key: String
    let title: String
    let authorName: [String]?
    let firstPublishYear: Int?
    let coverI: Int?
    let firstSentence: OLText?
    /// Populated by the `fields=*,editions` request — see `presentation`.
    let editions: OLEditions?
    /// Used to fetch the author record when the credit is in another
    /// script — see `withLatinAuthors`.
    let authorKey: [String]?

    enum CodingKeys: String, CodingKey {
        case key, title, editions
        case authorKey = "author_key"
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case coverI = "cover_i"
        case firstSentence = "first_sentence"
    }

    /// The title and cover to show for this hit.
    ///
    /// Open Library's `title` is the *work's* canonical title, which is the
    /// original language — so searching "kafka on the shore" returns
    /// 海辺のカフカ and "perfume" returns Das Parfum. The matched edition is
    /// the one the searcher meant.
    ///
    /// Title and cover are taken together, never mixed. "The Stranger" over
    /// the French cover reads as the wrong book, which is worse than simply
    /// showing the French title.
    var presentation: (title: String, coverID: Int?) {
        guard let edition = editions?.docs.first, let editionTitle = edition.title else {
            return (title, coverI)
        }
        return (editionTitle, edition.coverI ?? coverI)
    }
}

struct OLEditions: Decodable {
    let docs: [OLEdition]
}

struct OLEdition: Decodable {
    let title: String?
    let coverI: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case coverI = "cover_i"
    }
}

struct OLText: Decodable {
    let value: String
}

private struct OLSearchResponse: Decodable {
    let docs: [OLDoc]
}

/// Author record, fetched only when a credit needs its Latin form.
struct OLAuthorRecord: Decodable {
    let name: String?
    let personalName: String?

    enum CodingKeys: String, CodingKey {
        case name
        case personalName = "personal_name"
    }
}
