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
        let data = try await fetch(url: url)
        let response = try JSONDecoder().decode(OLSearchResponse.self, from: data)
        return response.docs.map(Self.candidate(from:))
    }

    // MARK: - Helpers (internal for tests)

    static func candidate(from doc: OLDoc) -> MediaCandidate {
        let coverURL = doc.coverI.map {
            coversBase.appending(path: "\($0)-M.jpg")
        }
        return MediaCandidate(
            title: doc.title,
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
        ]
        guard let url = components?.url else {
            preconditionFailure("Invalid OpenLibrary search URL")
        }
        return url
    }

    private func fetch(url: URL) async throws -> Data {
        do {
            let (data, response) = try await session.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw http.statusCode == 429 ? AppError.rateLimited : AppError.server
            }
            return data
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.from(error)
        }
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

    enum CodingKeys: String, CodingKey {
        case key, title
        case authorName = "author_name"
        case firstPublishYear = "first_publish_year"
        case coverI = "cover_i"
        case firstSentence = "first_sentence"
    }
}

struct OLText: Decodable {
    let value: String
}

private struct OLSearchResponse: Decodable {
    let docs: [OLDoc]
}
