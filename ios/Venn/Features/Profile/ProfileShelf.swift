import Foundation

/// The two shelves on a profile: things consumed vs. things saved for later.
/// Maps onto `post_action` — Collection is everything logged or rated,
/// Watchlist is everything saved.
enum ProfileShelf: String, CaseIterable, Identifiable {
    case collection
    case watchlist

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .collection: "Collection"
        case .watchlist: "Watchlist"
        }
    }

    /// `post_action` raw values that belong on this shelf.
    var actions: [String] {
        switch self {
        case .collection: ["logged", "rated"]
        case .watchlist: ["saved"]
        }
    }
}
