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
