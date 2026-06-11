import Foundation

/// Top-level Explorer category used by the segmented control.
/// Media categories map to one or more `MediaKind` values for search and
/// browse; `.people` searches profiles instead (social-first — finding
/// people sits right next to finding things).
enum ExplorerCategory: String, CaseIterable, Hashable, Identifiable {
    case all
    case people
    case movies
    case tv
    case music
    case books

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .all: "All"
        case .people: "People"
        case .movies: "Movies"
        case .tv: "TV"
        case .music: "Music"
        case .books: "Books"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .people: "person.2"
        case .movies: "film"
        case .tv: "tv"
        case .music: "music.note"
        case .books: "book.closed"
        }
    }

    /// The media kinds this category searches across (parallel for `.all`).
    /// Empty for `.people` — profile search goes through
    /// `PeopleSearchViewModel`, not the media catalog.
    var searchKinds: [MediaKind] {
        switch self {
        case .all: [.movie, .show, .album, .book]
        case .people: []
        case .movies: [.movie]
        case .tv: [.show]
        case .music: [.album]
        case .books: [.book]
        }
    }

    /// The single kind to load for the browse (recommendations) panel.
    /// Nil for `.all` and `.people` — those prompt for a search instead.
    var browseKind: MediaKind? {
        switch self {
        case .all, .people: nil
        case .movies: .movie
        case .tv: .show
        case .music: .album
        case .books: .book
        }
    }
}
