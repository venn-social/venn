import Foundation

/// Top-level Explorer category. Three for now (Movies / Music / Books) to
/// match the segmented control's tight rhythm. The schema also supports
/// `show`; it surfaces through Feed and lands in Explorer when the
/// design refresh expands the picker.
enum ExplorerCategory: String, CaseIterable, Hashable, Identifiable {
    case movies
    case music
    case books

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .movies: "Movies"
        case .music: "Music"
        case .books: "Books"
        }
    }

    var icon: String {
        switch self {
        case .movies: "film"
        case .music: "music.note"
        case .books: "book.closed"
        }
    }

    /// Map the UI category to the schema's `MediaKind`. "Music" surfaces
    /// albums today — there's no track-level media in the catalog yet.
    var mediaKind: MediaKind {
        switch self {
        case .movies: .movie
        case .music: .album
        case .books: .book
        }
    }
}
