import Foundation

/// Top-level Explorer category used by the segmented control.
/// Each case maps to one or more `MediaKind` values for search and browse.
enum ExplorerCategory: String, CaseIterable, Hashable, Identifiable {
    case all
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
        case .movies: "Movies"
        case .tv: "TV"
        case .music: "Music"
        case .books: "Books"
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .movies: "film"
        case .tv: "tv"
        case .music: "music.note"
        case .books: "book.closed"
        }
    }

    /// The media kinds this category searches across (parallel for `.all`).
    var searchKinds: [MediaKind] {
        switch self {
        case .all: [.movie, .show, .album, .book]
        case .movies: [.movie]
        case .tv: [.show]
        case .music: [.album]
        case .books: [.book]
        }
    }

    /// The single kind to load for the browse (recommendations) panel.
    /// Nil for `.all` — recommendations are skipped and search is prompted instead.
    var browseKind: MediaKind? {
        switch self {
        case .all: nil
        case .movies: .movie
        case .tv: .show
        case .music: .album
        case .books: .book
        }
    }

    /// Kept for call sites that need a single kind (e.g. ExplorerRecommendationCard).
    /// Falls back to `.movie` for `.all` — callers should prefer `browseKind`.
    var mediaKind: MediaKind {
        browseKind ?? .movie
    }
}
