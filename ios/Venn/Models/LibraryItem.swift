import Foundation

/// A `Post` joined with its `Media` — the building block for both the
/// watchlist (`action == .saved`) and the consumption collection
/// (`action == .logged || action == .rated`). Returned by
/// `ProfileServicing.watchlist(for:kind:)` and `collection(for:kind:)`.
struct LibraryItem: Identifiable, Equatable, Hashable {
    let post: Post
    let media: Media

    var id: UUID {
        post.id
    }
}

/// The one-tap library writes offered from a feed row. Mirrors web's
/// `FeedItemMenu` actions, in the same order and with the same labels.
enum LibraryQuickAction: String, CaseIterable, Identifiable {
    case log
    case watchlist

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .log: "Log"
        case .watchlist: "Add to Watchlist"
        }
    }

    var systemImage: String {
        switch self {
        case .log: "checkmark.circle"
        case .watchlist: "bookmark"
        }
    }

    /// Confirmation shown once the write lands — the only visible change is
    /// on a screen the reader is not looking at.
    var confirmation: String {
        switch self {
        case .log: "Added to your collection"
        case .watchlist: "Added to your watchlist"
        }
    }
}
