import Foundation

/// Domain model for a row in `public.media` — the polymorphic catalog of
/// things a user can log on venn (movies, shows, books, albums). Services
/// map `MediaSchema.Row` → `Media` so the rest of the app gets a typed
/// `kind` enum instead of a raw string.
struct Media: Identifiable, Equatable, Hashable {
    let id: UUID
    let kind: MediaKind
    let title: String
    let year: Int?
    let primaryCreator: String?
    let coverURL: URL?
    let externalID: String?
    let externalSource: ExternalSource?
    let createdAt: Date
}

/// Discriminator for the media catalog. Mirrors `public.media_kind`.
enum MediaKind: String, Codable, CaseIterable, Hashable {
    case movie
    case show
    case book
    case album

    /// Label for the "X logged a Y" verb-y action-line in the feed.
    var displayName: String {
        switch self {
        case .movie: "movie"
        case .show: "show"
        case .book: "book"
        case .album: "album"
        }
    }

    /// SF Symbol for this kind — cover placeholders, search-result rows,
    /// library badges. Defined once here; don't re-declare per feature.
    var systemImage: String {
        switch self {
        case .movie: "film"
        case .show: "tv"
        case .book: "book.closed"
        case .album: "music.note"
        }
    }
}

/// Origin of a `Media` row when sourced from an external catalog API.
/// Nil on the domain model when the user typed the entry by hand.
enum ExternalSource: String, Codable, Hashable {
    case tmdb // movies + shows
    case openlibrary // books
    case musicbrainz // albums
}

extension Media {
    /// Lift a DB row into the domain model. Returns nil if `kind` is an
    /// unknown enum value (forwards-compat: new kinds added to the DB
    /// won't crash older clients).
    init?(row: MediaSchema.Row) {
        guard let kind = MediaKind(rawValue: row.kind) else { return nil }
        id = row.id
        self.kind = kind
        title = row.title
        year = row.year
        primaryCreator = row.primaryCreator
        coverURL = row.coverUrl.flatMap(URL.init(string:))
        externalID = row.externalId
        externalSource = row.externalSource.flatMap(ExternalSource.init(rawValue:))
        createdAt = row.createdAt
    }
}
