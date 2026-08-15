import Foundation

/// TMDB (themoviedb.org) search for movies and TV shows.
///
/// Requires a TMDB v3 API key — free at https://developer.themoviedb.org.
/// Inject from `AppConfig.tmdbAPIKey`; never hardcode.
protocol TMDBServicing: Sendable {
    func searchMovies(query: String, page: Int) async throws -> [MediaCandidate]
    func searchShows(query: String, page: Int) async throws -> [MediaCandidate]
}

/// Production implementation backed by TMDB API v3.
///
/// Throwing paths map HTTP status codes and URLErrors to `AppError` so
/// callers see a single semantic error type (ADR 0006).
struct TMDBService: TMDBServicing {
    private static let base = URL(staticString: "https://api.themoviedb.org")
    static let posterBase = URL(staticString: "https://image.tmdb.org/t/p/w500")

    let apiKey: String
    let session: URLSession
    /// Which language TMDB should answer in. Defaults to English so a caller
    /// that has not been given one still works, rather than failing to build.
    let language: AppLanguage

    init(apiKey: String, language: AppLanguage = .en, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.language = language
        self.session = session
    }

    func searchMovies(query: String, page: Int = 1) async throws -> [MediaCandidate] {
        let url = Self.searchURL(
            path: "/3/search/movie",
            query: query,
            page: page,
            apiKey: apiKey,
            language: language
        )
        let data = try await ExternalAPI.fetch(url: url, session: session)
        let response = try JSONDecoder().decode(TMDBMovieSearchResponse.self, from: data)
        return response.results.map(Self.candidate(from:))
    }

    func searchShows(query: String, page: Int = 1) async throws -> [MediaCandidate] {
        let url = Self.searchURL(
            path: "/3/search/tv",
            query: query,
            page: page,
            apiKey: apiKey,
            language: language
        )
        let data = try await ExternalAPI.fetch(url: url, session: session)
        let response = try JSONDecoder().decode(TMDBShowSearchResponse.self, from: data)
        return response.results.map(Self.candidate(from:))
    }

    // MARK: - Helpers (internal so tests can invoke directly)

    static func candidate(from movie: TMDBMovie) -> MediaCandidate {
        MediaCandidate(
            title: movie.title,
            primaryCreator: nil,
            year: ExternalAPI.year(from: movie.releaseDate),
            coverURL: movie.posterPath.map { posterBase.appending(path: $0) },
            overview: movie.overview.flatMap { $0.isEmpty ? nil : $0 },
            externalID: String(movie.id),
            externalSource: .tmdb,
            kind: .movie
        )
    }

    static func candidate(from show: TMDBShow) -> MediaCandidate {
        MediaCandidate(
            title: show.name,
            primaryCreator: nil,
            year: ExternalAPI.year(from: show.firstAirDate),
            coverURL: show.posterPath.map { posterBase.appending(path: $0) },
            overview: show.overview.flatMap { $0.isEmpty ? nil : $0 },
            externalID: String(show.id),
            externalSource: .tmdb,
            kind: .show
        )
    }

    // MARK: - Helpers (internal for tests)

    static func searchURL(
        path: String,
        query: String,
        page: Int,
        apiKey: String,
        language: AppLanguage
    ) -> URL {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = path
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            // TMDB returns the title as released in this language, which is
            // the whole point of the setting.
            URLQueryItem(name: "language", value: language.tmdbLanguage),
        ]
        guard let url = components?.url else {
            preconditionFailure("Invalid TMDB search URL for path \(path)")
        }
        return url
    }
}

// MARK: - Wire format (internal for @testable import in tests)

struct TMDBMovie: Decodable {
    let id: Int
    let title: String
    let releaseDate: String?
    let posterPath: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id, title, overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
    }
}

struct TMDBShow: Decodable {
    let id: Int
    let name: String
    let firstAirDate: String?
    let posterPath: String?
    let overview: String?

    enum CodingKeys: String, CodingKey {
        case id, name, overview
        case firstAirDate = "first_air_date"
        case posterPath = "poster_path"
    }
}

private struct TMDBMovieSearchResponse: Decodable {
    let results: [TMDBMovie]
}

private struct TMDBShowSearchResponse: Decodable {
    let results: [TMDBShow]
}
