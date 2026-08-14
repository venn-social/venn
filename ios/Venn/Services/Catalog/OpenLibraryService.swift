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

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchBooks(query: String, page: Int = 1) async throws -> [MediaCandidate] {
        let url = Self.searchURL(query: query, page: page)
        let data = try await ExternalAPI.fetch(url: url, session: session)
        let response = try JSONDecoder().decode(OLSearchResponse.self, from: data)
        return response.docs.map(Self.candidate(from:))
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

    enum CodingKeys: String, CodingKey {
        case key, title, editions
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
