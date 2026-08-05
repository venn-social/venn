import Foundation

/// One credited person — an actor, author, or artist.
struct Credit: Equatable, Hashable, Sendable {
    let name: String
    /// The character played, for screen credits. Nil elsewhere.
    let role: String?
}

/// Somewhere you can watch or listen to this.
struct WatchLink: Equatable, Hashable, Sendable {
    /// How it's available. "On Netflix" and "£13.99 to buy" are different
    /// answers, and TMDB distinguishes them.
    enum Kind: String, Equatable, Hashable, Sendable {
        case stream, rent, buy, link

        var label: String {
            switch self {
            case .stream: "Stream"
            case .rent: "Rent"
            case .buy: "Buy"
            case .link: "Watch"
            }
        }
    }

    let provider: String
    let kind: Kind
    let url: URL?
    let logoURL: URL?
}

/// Everything worth knowing about one title, normalised across providers.
///
/// Every field is optional because the three catalogs disagree wildly
/// about what they hold: TMDB has cast and runtime, OpenLibrary has page
/// counts and subjects, MusicBrainz has neither but knows the label. The
/// view skips what's missing rather than rendering blanks.
struct MediaDetail: Equatable, Sendable {
    var overview: String?
    /// Actors for screen, authors for books, artists for music.
    var credits: [Credit] = []
    /// Directors and showrunners — the authorial credit, kept apart from
    /// cast because it answers a different question.
    var creators: [Credit] = []
    var genres: [String] = []
    /// Minutes for screen; nil elsewhere.
    var runtime: Int?
    var releaseDate: String?
    /// Out of 10, as TMDB reports it.
    var rating: Double?
    var watchLinks: [WatchLink] = []
    /// ISO country the watch links apply to — availability is regional,
    /// and a provider list without a country is a claim we can't support.
    var watchRegion: String?
    /// Deep link back to the source, so people can go read more.
    var sourceURL: URL?

    static let empty = MediaDetail()

    /// "2h 17m" from the minute count. Nil passes through so the view can
    /// skip the field entirely rather than render a placeholder.
    var formattedRuntime: String? {
        guard let runtime, runtime > 0 else { return nil }
        let hours = runtime / 60
        let minutes = runtime % 60
        return switch (hours, minutes) {
        case (0, _): "\(minutes)m"
        case (_, 0): "\(hours)h"
        default: "\(hours)h \(minutes)m"
        }
    }

    /// "United Kingdom" from "GB", falling back to the raw code. The region
    /// is always stated next to the watch links: streaming rights differ by
    /// country, so a bare provider list is a claim we can't support.
    var watchRegionName: String? {
        guard let watchRegion else { return nil }
        return Locale.current.localizedString(forRegionCode: watchRegion) ?? watchRegion
    }
}

/// Enriched detail for a catalog item. Behind a protocol so view-models
/// unit-test with a fake (ADR 0005).
protocol MediaDetailServicing: Sendable {
    func detail(for media: Media, region: String) async throws -> MediaDetail
}

/// Production implementation. Calls the same three catalogs the composer
/// searches, using the existing per-provider services.
struct MediaDetailService: MediaDetailServicing {
    /// Nil when the build has no TMDB key: books and albums still work,
    /// movies and shows report why they can't.
    private let tmdbAPIKey: String?
    private let session: URLSession

    init(tmdbAPIKey: String?, session: URLSession = .shared) {
        self.tmdbAPIKey = tmdbAPIKey
        self.session = session
    }

    func detail(for media: Media, region: String) async throws -> MediaDetail {
        guard let source = media.externalSource, let externalID = media.externalID else {
            // Hand-typed rows have nothing to enrich from.
            return .empty
        }

        var detail: MediaDetail = switch source {
        case .tmdb:
            try await tmdbDetail(media: media, externalID: externalID, region: region)
        case .openlibrary:
            try await OpenLibraryDetail.fetch(workID: externalID, session: session)
        case .musicbrainz:
            try await MusicBrainzDetail.fetch(releaseGroupID: externalID, session: session)
        }

        detail.sourceURL = Self.sourceURL(source: source, kind: media.kind, externalID: externalID)
        return detail
    }

    private func tmdbDetail(
        media: Media,
        externalID: String,
        region: String
    ) async throws -> MediaDetail {
        guard let tmdbAPIKey, !tmdbAPIKey.isEmpty else {
            throw AppError.validation("Movie and show details need a TMDB API key.")
        }
        return try await TMDBDetail.fetch(
            kind: media.kind,
            externalID: externalID,
            apiKey: tmdbAPIKey,
            region: region,
            session: session
        )
    }

    /// Where to send someone who wants the full record. Linking out is more
    /// honest than pretending we hold everything.
    static func sourceURL(source: ExternalSource, kind: MediaKind, externalID: String) -> URL? {
        switch source {
        case .tmdb:
            URL(string: "https://www.themoviedb.org/\(kind == .movie ? "movie" : "tv")/\(externalID)")
        case .openlibrary:
            URL(string: "https://openlibrary.org/works/\(externalID)")
        case .musicbrainz:
            URL(string: "https://musicbrainz.org/release-group/\(externalID)")
        }
    }
}

/// The region whose availability to show. iOS knows the device's region
/// directly, which is a better signal than anything a server can infer.
enum WatchRegion {
    static var current: String {
        Locale.current.region?.identifier ?? "GB"
    }
}
