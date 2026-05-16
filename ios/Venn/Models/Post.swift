import Foundation

/// Domain model for a row in `public.posts` — a single feed item about
/// something the author consumed. Services map `PostsSchema.Row` → `Post`
/// so the rest of the app gets a typed `action` enum instead of a raw
/// string.
struct Post: Identifiable, Equatable, Hashable {
    let id: UUID
    let authorID: UUID
    let mediaID: UUID
    let action: PostAction
    let rating: Double?
    let caption: String?
    let createdAt: Date
}

/// The verb attached to a post. Mirrors `public.post_action`.
enum PostAction: String, Codable, CaseIterable, Hashable {
    /// Author consumed the media (watched / read / listened).
    case logged
    /// Author gave the media an explicit numeric rating.
    case rated
    /// Author added it to their list of intended-to-consume items.
    case saved
}

extension Post {
    /// Lift a DB row into the domain model. Returns nil if `action` is an
    /// unknown enum value (forwards-compat).
    init?(row: PostsSchema.Row) {
        guard let action = PostAction(rawValue: row.action) else { return nil }
        id = row.id
        authorID = row.authorId
        mediaID = row.mediaId
        self.action = action
        rating = row.rating
        caption = row.caption
        createdAt = row.createdAt
    }
}

/// A `Post` joined with its `Media` and author `UserProfile`. This is what
/// `FeedService` returns and what `FeedView` renders.
struct FeedPost: Identifiable, Equatable, Hashable {
    let post: Post
    let media: Media
    let author: UserProfile

    var id: UUID {
        post.id
    }
}
