import Foundation

/// Behind a protocol so the view-model unit-tests with a fake (ADR 0005).
protocol CatalogSimilarServicing: Sendable {
    func similar(to seed: RecommendationSeed) async throws -> [MediaCandidate]
    func trending() async throws -> [MediaCandidate]
}

/// Things like what you loved, and what is popular now.
///
/// Film and TV get TMDB's own recommendations — real collaborative
/// filtering computed from millions of users, which is what lets venn
/// recommend from a user's first log instead of needing scale first.
/// Books and music have no equivalent and fall back to the same subject or
/// the same artist; the shelf copy says so rather than implying a taste
/// match we cannot support.
struct CatalogSimilarService: CatalogSimilarServicing {
    private static let tmdbBase = "https://api.themoviedb.org/3"
    private static let openLibraryBase = "https://openlibrary.org"
    private static let musicBrainzBase = "https://musicbrainz.org/ws/2"
    private static let userAgent = "Venn/1.0 (social.venn.app)"
    private static let posterBase = "https://image.tmdb.org/t/p/w500"

    private let tmdbAPIKey: String?
    private let session: URLSession

    init(tmdbAPIKey: String?, session: URLSession = .shared) {
        self.tmdbAPIKey = tmdbAPIKey
        self.session = session
    }

    func similar(to seed: RecommendationSeed) async throws -> [MediaCandidate] {
        switch seed.externalSource {
        case .tmdb: try await tmdbSimilar(to: seed)
        case .openlibrary: try await openLibrarySimilar(to: seed)
        case .musicbrainz: try await musicBrainzSimilar(to: seed)
        }
    }

    func trending() async throws -> [MediaCandidate] {
        guard let tmdbAPIKey, !tmdbAPIKey.isEmpty,
              let url = URL(string: "\(Self.tmdbBase)/trending/all/week?api_key=\(tmdbAPIKey)")
        else { return [] }

        let data = try await ExternalAPI.fetch(url: url, session: session)
        return try Self.trendingCandidates(from: data)
    }

    // MARK: - Per-provider

    private func tmdbSimilar(to seed: RecommendationSeed) async throws -> [MediaCandidate] {
        guard let tmdbAPIKey, !tmdbAPIKey.isEmpty else { return [] }
        let path = seed.kind == .movie ? "movie" : "tv"
        let raw = "\(Self.tmdbBase)/\(path)/\(seed.externalID)/recommendations?api_key=\(tmdbAPIKey)"
        guard let url = URL(string: raw) else { return [] }

        let data = try await ExternalAPI.fetch(url: url, session: session)
        return try Self.tmdbCandidates(from: data, kind: seed.kind)
    }

    /// Two calls: the work to find a subject, then that subject's other
    /// books. OpenLibrary has no "similar" endpoint at all.
    private func openLibrarySimilar(to seed: RecommendationSeed) async throws -> [MediaCandidate] {
        guard let workURL = URL(string: "\(Self.openLibraryBase)/works/\(seed.externalID).json")
        else { return [] }

        let workData = try await ExternalAPI.fetch(url: workURL, session: session)
        guard let subject = try JSONDecoder()
            .decode(OLWorkSubjects.self, from: workData)
            .subjects?.first
        else { return [] }

        let slug = subject.lowercased().replacingOccurrences(of: " ", with: "_")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard let encoded = slug.addingPercentEncoding(withAllowedCharacters: allowed),
              let subjectURL = URL(
                  string: "\(Self.openLibraryBase)/subjects/\(encoded).json?limit=20"
              )
        else { return [] }

        let subjectData = try await ExternalAPI.fetch(url: subjectURL, session: session)
        return try Self.bookCandidates(from: subjectData)
    }

    /// Two calls again: the release-group to find its artist, then that
    /// artist's other release-groups. Browsing by artist needs an MBID the
    /// seed does not carry.
    private func musicBrainzSimilar(to seed: RecommendationSeed) async throws -> [MediaCandidate] {
        let groupRaw = "\(Self.musicBrainzBase)/release-group/\(seed.externalID)?inc=artists&fmt=json"
        guard let groupURL = URL(string: groupRaw) else { return [] }

        let groupData = try await ExternalAPI.fetch(
            url: groupURL, session: session, userAgent: Self.userAgent
        )
        guard let artistID = try JSONDecoder()
            .decode(MBGroupWithArtist.self, from: groupData)
            .artistCredit?.first?.artist?.id
        else { return [] }

        let browseRaw = "\(Self.musicBrainzBase)/release-group?artist=\(artistID)&fmt=json&limit=20"
        guard let browseURL = URL(string: browseRaw) else { return [] }

        let browseData = try await ExternalAPI.fetch(
            url: browseURL, session: session, userAgent: Self.userAgent
        )
        let browsed = try JSONDecoder().decode(MBBrowseResponse.self, from: browseData)
        // Drop the seed itself — "more from this artist" should not lead
        // with the album you just rated.
        return browsed.releaseGroups
            .filter { $0.id != seed.externalID }
            .map(MusicBrainzService.candidate(from:))
    }

    // MARK: - TMDB mapping

    /// `/trending/all/week` returns movies, shows **and people** in one
    /// list. People are not something you can log, so they are dropped
    /// rather than rendered as a coverless card.
    static func trendingCandidates(from data: Data) throws -> [MediaCandidate] {
        let response = try JSONDecoder().decode(TMDBListResponse.self, from: data)
        return (response.results ?? []).compactMap { result in
            let kind: MediaKind? = switch result.mediaType {
            case "movie": .movie
            case "tv": .show
            default: nil
            }
            guard let kind else { return nil }
            return candidate(from: result, kind: kind)
        }
    }

    /// The `/recommendations` payload has the same shape as `/trending`
    /// minus `media_type`, so the kind is supplied by the caller.
    static func tmdbCandidates(from data: Data, kind: MediaKind) throws -> [MediaCandidate] {
        let response = try JSONDecoder().decode(TMDBListResponse.self, from: data)
        return (response.results ?? []).compactMap { candidate(from: $0, kind: kind) }
    }

    private static func candidate(from result: TMDBListResult, kind: MediaKind) -> MediaCandidate? {
        guard let id = result.id, let title = result.title ?? result.name else { return nil }

        return MediaCandidate(
            title: title,
            primaryCreator: nil,
            year: ExternalAPI.year(from: result.releaseDate ?? result.firstAirDate),
            coverURL: result.posterPath.flatMap { URL(string: Self.posterBase + $0) },
            overview: result.overview,
            externalID: String(id),
            externalSource: .tmdb,
            kind: kind
        )
    }

    // MARK: - OpenLibrary mapping

    /// The `/subjects/{name}.json` payload, which is a different shape from
    /// search — `works` rather than `docs`, `cover_id` rather than
    /// `cover_i` — so `OpenLibraryService`'s search mapper cannot decode it.
    static func bookCandidates(from data: Data) throws -> [MediaCandidate] {
        let response = try JSONDecoder().decode(OLSubjectResponse.self, from: data)
        return (response.works ?? []).map { work in
            MediaCandidate(
                title: work.title,
                primaryCreator: work.authors?.first?.name,
                year: work.firstPublishYear,
                coverURL: work.coverID.flatMap {
                    // -L, matching OpenLibraryService — see the note there.
                    URL(string: "https://covers.openlibrary.org/b/id/\($0)-L.jpg")
                },
                overview: nil,
                // Strip the "/works/" prefix so external_id matches what
                // OpenLibraryService.workKey(from:) produces.
                externalID: work.key.replacingOccurrences(of: "/works/", with: ""),
                externalSource: .openlibrary,
                kind: .book
            )
        }
    }
}

// MARK: - Wire formats

/// Shared by `/trending/all/week` and `/{movie,tv}/{id}/recommendations`.
struct TMDBListResponse: Decodable {
    let results: [TMDBListResult]?
}

struct TMDBListResult: Decodable {
    let id: Int?
    let mediaType: String?
    let title: String?
    let name: String?
    let releaseDate: String?
    let firstAirDate: String?
    let posterPath: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case mediaType = "media_type"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
    }
}

struct OLWorkSubjects: Decodable {
    let subjects: [String]?
}

struct OLSubjectResponse: Decodable {
    let works: [OLSubjectWork]?
}

struct OLSubjectWork: Decodable {
    let key: String
    let title: String
    let authors: [OLSubjectAuthor]?
    let firstPublishYear: Int?
    let coverID: Int?

    enum CodingKeys: String, CodingKey {
        case key, title, authors
        case firstPublishYear = "first_publish_year"
        case coverID = "cover_id"
    }
}

struct OLSubjectAuthor: Decodable {
    let name: String?
}

/// `MusicBrainzService`'s own response wrapper is private, so this declares
/// its own. `MBReleaseGroup` and `candidate(from:)` are internal and reused
/// rather than duplicated.
struct MBBrowseResponse: Decodable {
    let releaseGroups: [MBReleaseGroup]

    enum CodingKeys: String, CodingKey {
        case releaseGroups = "release-groups"
    }
}

struct MBGroupWithArtist: Decodable {
    let artistCredit: [MBCreditWithArtist]?

    enum CodingKeys: String, CodingKey {
        case artistCredit = "artist-credit"
    }
}

struct MBCreditWithArtist: Decodable {
    let artist: MBArtistRef?
}

struct MBArtistRef: Decodable {
    let id: String
}
