import Foundation

// Per-provider detail fetching and normalisation.
//
// Kept apart from `MediaDetailService` so each catalog's quirks stay in
// one place, mirroring how `Services/Catalog/` splits search. The
// `detail(from:)` functions are pure and internal so tests can exercise
// the mapping — which is where these three APIs differ most — without a
// network call.
//
// Wire types sit at file scope rather than nested inside the enums:
// SwiftLint caps nesting at one level, and a `Response.Credits.Person`
// chain would breach it.

// MARK: - TMDB wire format

struct TMDBPerson: Decodable {
    let name: String?
    let character: String?
    let job: String?
}

struct TMDBProviderEntry: Decodable {
    let providerName: String?
    let logoPath: String?

    enum CodingKeys: String, CodingKey {
        case providerName = "provider_name"
        case logoPath = "logo_path"
    }
}

struct TMDBRegionProviders: Decodable {
    let link: String?
    let flatrate: [TMDBProviderEntry]?
    let rent: [TMDBProviderEntry]?
    let buy: [TMDBProviderEntry]?
}

struct TMDBGenre: Decodable {
    let name: String?
}

struct TMDBCredits: Decodable {
    let cast: [TMDBPerson]?
    let crew: [TMDBPerson]?
}

struct TMDBWatchProviders: Decodable {
    let results: [String: TMDBRegionProviders]?
}

struct TMDBDetailResponse: Decodable {
    let overview: String?
    let runtime: Int?
    let episodeRunTime: [Int]?
    let genres: [TMDBGenre]?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let credits: TMDBCredits?
    let createdBy: [TMDBPerson]?
    let watchProviders: TMDBWatchProviders?

    enum CodingKeys: String, CodingKey {
        case overview, runtime, genres, credits
        case episodeRunTime = "episode_run_time"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case createdBy = "created_by"
        case watchProviders = "watch/providers"
    }
}

enum TMDBDetail {
    private static let base = "https://api.themoviedb.org/3"
    private static let logoBase = "https://image.tmdb.org/t/p/w92"

    /// Internal for tests.
    static func detail(from response: TMDBDetailResponse, region: String) -> MediaDetail {
        var detail = MediaDetail()
        detail.overview = response.overview?.isEmpty == false ? response.overview : nil
        detail.credits = (response.credits?.cast ?? [])
            .prefix(12)
            .compactMap { person in
                person.name.map { Credit(name: $0, role: person.character) }
            }
        // Directors for film, creators for television. A full crew list runs
        // to hundreds of names; the gaffer isn't what anyone came for.
        detail.creators = ((response.createdBy ?? [])
            + (response.credits?.crew ?? []).filter { $0.job == "Director" })
            .compactMap { person in
                person.name.map { Credit(name: $0, role: person.job ?? "Director") }
            }
        detail.genres = (response.genres ?? []).compactMap(\.name)
        detail.runtime = response.runtime ?? response.episodeRunTime?.first
        detail.releaseDate = response.releaseDate ?? response.firstAirDate
        detail.rating = response.voteAverage
        detail.watchLinks = watchLinks(from: response, region: region)
        detail.watchRegion = region
        return detail
    }

    static func watchLinks(from response: TMDBDetailResponse, region: String) -> [WatchLink] {
        guard let forRegion = response.watchProviders?.results?[region] else { return [] }

        let url = forRegion.link.flatMap(URL.init(string:))
        let groups: [([TMDBProviderEntry]?, WatchLink.Kind)] = [
            (forRegion.flatrate, .stream),
            (forRegion.rent, .rent),
            (forRegion.buy, .buy),
        ]

        // A provider often appears under several kinds; the first — and
        // cheapest, since stream comes before rent before buy — is the
        // useful answer. Listing it twice implies you must pay.
        var seen = Set<String>()
        var links: [WatchLink] = []
        for (providers, kind) in groups {
            for provider in providers ?? [] {
                guard let name = provider.providerName, !seen.contains(name) else { continue }
                seen.insert(name)
                links.append(
                    WatchLink(
                        provider: name,
                        kind: kind,
                        // TMDB returns one link per region, not per provider.
                        url: url,
                        logoURL: provider.logoPath.flatMap { URL(string: logoBase + $0) }
                    )
                )
            }
        }
        return links
    }

    static func fetch(
        kind: MediaKind,
        externalID: String,
        apiKey: String,
        region: String,
        session: URLSession
    ) async throws -> MediaDetail {
        let path = kind == .movie ? "movie" : "tv"
        let raw =
            "\(base)/\(path)/\(externalID)?api_key=\(apiKey)&append_to_response=credits,watch/providers"
        guard let url = URL(string: raw) else {
            throw AppError.unknown(message: "Could not build the TMDB detail URL")
        }

        let data = try await ExternalAPI.fetch(url: url, session: session)
        let response = try JSONDecoder().decode(TMDBDetailResponse.self, from: data)
        return detail(from: response, region: region)
    }
}

// MARK: - OpenLibrary wire format

/// OpenLibrary returns `description` as either a bare string or an object,
/// depending on how old the record is.
enum OLDescription: Decodable {
    case text(String)

    var value: String {
        switch self {
        case let .text(value): value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let raw = try? container.decode(String.self) {
            self = .text(raw)
            return
        }
        self = try .text(container.decode(OLDescriptionObject.self).value)
    }
}

struct OLDescriptionObject: Decodable {
    let value: String
}

struct OLAuthorKey: Decodable {
    let key: String?
}

struct OLAuthorRef: Decodable {
    let author: OLAuthorKey?
}

struct OLAuthorName: Decodable {
    let name: String?
}

struct OLWork: Decodable {
    let description: OLDescription?
    let subjects: [String]?
    let firstPublishDate: String?
    let authors: [OLAuthorRef]?

    enum CodingKeys: String, CodingKey {
        case description, subjects, authors
        case firstPublishDate = "first_publish_date"
    }
}

enum OpenLibraryDetail {
    private static let base = "https://openlibrary.org"

    /// Internal for tests.
    static func detail(from work: OLWork, authorNames: [String]) -> MediaDetail {
        var detail = MediaDetail()
        detail.overview = work.description?.value
        // Books have authors, not a cast — credits stays empty rather than
        // duplicating them.
        detail.creators = authorNames.map { Credit(name: $0, role: "Author") }
        // Subjects are OpenLibrary's genres, and records often carry dozens.
        detail.genres = Array((work.subjects ?? []).prefix(8))
        detail.releaseDate = work.firstPublishDate
        return detail
    }

    static func fetch(workID: String, session: URLSession) async throws -> MediaDetail {
        guard let url = URL(string: "\(base)/works/\(workID).json") else {
            throw AppError.unknown(message: "Could not build the OpenLibrary detail URL")
        }
        let data = try await ExternalAPI.fetch(url: url, session: session)
        let work = try JSONDecoder().decode(OLWork.self, from: data)

        // Authors are stored by reference, so names need a second round of
        // lookups. A failed one is skipped rather than failing the page.
        let keys = (work.authors ?? []).compactMap(\.author?.key).prefix(5)
        var names: [String] = []
        for key in keys {
            if let name = await authorName(key: key, session: session) {
                names.append(name)
            }
        }

        return detail(from: work, authorNames: names)
    }

    /// One author's name. Returns nil rather than throwing: a missing name
    /// should thin the credits, not fail the whole page.
    private static func authorName(key: String, session: URLSession) async -> String? {
        guard let url = URL(string: "\(base)\(key).json") else { return nil }
        guard let data = try? await ExternalAPI.fetch(url: url, session: session) else {
            return nil
        }
        return try? JSONDecoder().decode(OLAuthorName.self, from: data).name
    }
}

// MARK: - MusicBrainz wire format

struct MBArtist: Decodable {
    let name: String?
}

struct MBArtistCreditEntry: Decodable {
    let name: String?
    let artist: MBArtist?
}

struct MBTag: Decodable {
    let name: String?
    let count: Int?
}

struct MBDetailResponse: Decodable {
    let artistCredit: [MBArtistCreditEntry]?
    let firstReleaseDate: String?
    let tags: [MBTag]?

    enum CodingKeys: String, CodingKey {
        case tags
        case artistCredit = "artist-credit"
        case firstReleaseDate = "first-release-date"
    }
}

enum MusicBrainzDetail {
    private static let base = "https://musicbrainz.org/ws/2"
    private static let userAgent = "Venn/1.0 (social.venn.app)"

    /// Internal for tests.
    static func detail(from response: MBDetailResponse) -> MediaDetail {
        var detail = MediaDetail()
        // MusicBrainz holds no editorial description — it's a structured
        // database, not a review site. Nil is honest; synthesising a summary
        // from tags would not be.
        detail.overview = nil
        detail.creators = (response.artistCredit ?? [])
            .compactMap { $0.artist?.name ?? $0.name }
            .map { Credit(name: $0, role: "Artist") }
        // Community tags are the closest thing to genre, ordered by how many
        // people applied them.
        detail.genres = (response.tags ?? [])
            .sorted { ($0.count ?? 0) > ($1.count ?? 0) }
            .compactMap(\.name)
            .prefix(6)
            .map(\.self)
        detail.releaseDate = response.firstReleaseDate
        return detail
    }

    static func fetch(releaseGroupID: String, session: URLSession) async throws -> MediaDetail {
        let raw = "\(base)/release-group/\(releaseGroupID)?inc=artists+tags&fmt=json"
        guard let url = URL(string: raw) else {
            throw AppError.unknown(message: "Could not build the MusicBrainz detail URL")
        }
        let data = try await ExternalAPI.fetch(url: url, session: session, userAgent: userAgent)
        return try detail(from: JSONDecoder().decode(MBDetailResponse.self, from: data))
    }
}
