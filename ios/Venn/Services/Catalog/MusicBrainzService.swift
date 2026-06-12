import Foundation

/// MusicBrainz (musicbrainz.org) search for albums. No API key required.
///
/// MusicBrainz ToS requires:
///   1. A `User-Agent` header identifying the app and contact URL.
///   2. A maximum of 1 request per second without a commercial agreement.
///      The UI layer must debounce search queries; this service does not
///      enforce the rate limit internally.
///
/// Cover art is not included in search results, but the Cover Art Archive
/// (coverartarchive.org) front-cover URL is derivable from the release
/// group's MBID alone — no lookup request. Release groups without art 404
/// at render time, which lands on `MediaCoverTile`'s tonal fallback.
protocol MusicBrainzServicing: Sendable {
    func searchAlbums(query: String, page: Int) async throws -> [MediaCandidate]
}

/// Production implementation backed by the MusicBrainz Search API v2.
struct MusicBrainzService: MusicBrainzServicing {
    private static let base = URL(staticString: "https://musicbrainz.org")
    private static let pageSize = 20
    private static let userAgent = "Venn/1.0 (social.venn.app)"

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchAlbums(query: String, page: Int = 1) async throws -> [MediaCandidate] {
        let offset = (page - 1) * Self.pageSize
        let url = Self.searchURL(query: query, limit: Self.pageSize, offset: offset)
        let data = try await ExternalAPI.fetch(url: url, session: session, userAgent: Self.userAgent)
        let response = try JSONDecoder().decode(MBReleaseGroupSearchResponse.self, from: data)
        return response.releaseGroups.map(Self.candidate(from:))
    }

    // MARK: - Helpers (internal for tests)

    static func candidate(from group: MBReleaseGroup) -> MediaCandidate {
        MediaCandidate(
            title: group.title,
            primaryCreator: group.artistCredit?.first?.name,
            year: ExternalAPI.year(from: group.firstReleaseDate),
            coverURL: coverURL(releaseGroupID: group.id),
            overview: nil,
            externalID: group.id,
            externalSource: .musicbrainz,
            kind: .album
        )
    }

    /// Cover Art Archive front cover for a release group, 500px edition —
    /// the same pixel budget as TMDB's w500 posters. Constructed blind:
    /// CAA 404s when no art exists and the cover tile falls back to the
    /// tonal placeholder, so a wrong guess costs nothing.
    static func coverURL(releaseGroupID: String) -> URL? {
        URL(string: "https://coverartarchive.org/release-group/\(releaseGroupID)/front-500")
    }

    private static func searchURL(query: String, limit: Int, offset: Int) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = "/ws/2/release-group"
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ]
        guard let url = components?.url else {
            preconditionFailure("Invalid MusicBrainz search URL")
        }
        return url
    }
}

// MARK: - Wire format (internal for @testable import in tests)

struct MBReleaseGroup: Decodable {
    let id: String
    let title: String
    let artistCredit: [MBArtistCredit]?
    let firstReleaseDate: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case artistCredit = "artist-credit"
        case firstReleaseDate = "first-release-date"
    }
}

struct MBArtistCredit: Decodable {
    /// The credited name as it appears on the release (may differ from the
    /// canonical artist name, e.g. "Jay-Z & Kanye West" for a collab).
    let name: String
}

private struct MBReleaseGroupSearchResponse: Decodable {
    let releaseGroups: [MBReleaseGroup]

    enum CodingKeys: String, CodingKey {
        case releaseGroups = "release-groups"
    }
}
