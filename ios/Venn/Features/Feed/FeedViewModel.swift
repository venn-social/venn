import Foundation
import Observation

/// Loads recent posts and exposes them through a single `state` enum.
/// `FeedView` pattern-matches on it directly (loading / loaded / error)
/// the same way `ProfileViewModel` does — keeps the view free of
/// imperative `if/else` over an async load.
///
/// Pagination is keyset-based: `loadMore()` fetches posts strictly older
/// than the last one shown and appends them into the loaded state.
/// `hasMore` drives the view's footer spinner — a full page implies more
/// may exist; a short page means the feed is exhausted.
///
/// What lands in the feed (people you follow + you) is the service's
/// concern — this model just renders whatever `recentPosts` returns.
@MainActor
@Observable
final class FeedViewModel {
    typealias State = LoadState<[FeedPost]>

    private(set) var state: State = .loading
    private(set) var isLoadingMore = false
    private(set) var hasMore = false

    /// Likes and comment counts, keyed by post id. Missing entries render
    /// as zero rather than blocking the row — see `loadSocial`.
    private(set) var social: [UUID: PostSocial] = [:]

    private let service: any FeedServicing
    private let socialService: (any SocialServicing)?
    private let pageSize: Int

    init(
        service: any FeedServicing,
        socialService: (any SocialServicing)? = nil,
        pageSize: Int = 20
    ) {
        self.service = service
        self.socialService = socialService
        self.pageSize = pageSize
    }

    /// Confirmation for the last completed quick action, cleared once
    /// shown. Kept here rather than in the row so it survives the row being
    /// recycled by the list.
    var lastQuickActionMessage: String?

    /// Log or save a feed item into the signed-in user's own library.
    ///
    /// Fire-and-forget from the row's point of view: nothing on this screen
    /// changes, so the only feedback is the confirmation string.
    func performQuickAction(
        _ action: LibraryQuickAction,
        mediaID: UUID,
        viewerID: UUID
    ) async {
        do {
            switch action {
            case .log:
                try await service.logFromFeed(authorID: viewerID, mediaID: mediaID)
            case .watchlist:
                try await service.saveToWatchlist(authorID: viewerID, mediaID: mediaID)
            }
            lastQuickActionMessage = action.confirmation
        } catch {
            lastQuickActionMessage = "Couldn't do that. Please try again."
        }
    }

    func social(for postID: UUID) -> PostSocial {
        social[postID] ?? .none
    }

    /// Full reload through the `.loading` state. Safe to call on retry.
    func load() async {
        state = .loading
        await refresh()
    }

    /// Refetches the first page in place (pull-to-refresh). If the fetch
    /// fails while content is already on screen, the stale content stays —
    /// yanking a visible feed for a transient network blip is worse than
    /// silently keeping it.
    func refresh() async {
        do {
            let posts = try await service.recentPosts(limit: pageSize, before: nil)
            hasMore = posts.count == pageSize
            state = .loaded(posts)
            await loadSocial(for: posts)
        } catch let error as AppError {
            if case .loaded = state {
                return
            }
            state = .error(LoadErrorReason(error))
        } catch {
            if case .loaded = state {
                return
            }
            state = .error(.unknown)
        }
    }

    /// Appends the next (strictly older) page. No-ops unless there's a
    /// loaded feed with more to fetch and no page already in flight.
    func loadMore() async {
        guard case let .loaded(current) = state, hasMore, !isLoadingMore,
              let cursor = current.last?.post.createdAt
        else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let next = try await service.recentPosts(limit: pageSize, before: cursor)
            hasMore = next.count == pageSize
            // Keyset paging shouldn't overlap, but a post created in the
            // same instant as the cursor could; never show a row twice.
            let seen = Set(current.map(\.id))
            let appended = next.filter { !seen.contains($0.id) }
            state = .loaded(current + appended)
            await loadSocial(for: appended)
        } catch {
            // Stop paging rather than let the footer retrigger an error
            // loop; pull-to-refresh restarts pagination from the top.
            hasMore = false
        }
    }

    /// Likes and comment counts for a page of posts — two calls for the
    /// whole page rather than two per row, which for 20 posts would be 40
    /// extra round trips.
    ///
    /// Failures are swallowed on purpose. These counts are decoration; the
    /// feed is the content. A row with no heart beside it is a far better
    /// outcome than an error screen where the feed used to be.
    private func loadSocial(for posts: [FeedPost]) async {
        guard let socialService, !posts.isEmpty else { return }
        let postIDs = posts.map(\.id)

        async let likes = try? socialService.likeInfo(postIDs: postIDs)
        async let counts = try? socialService.commentCounts(postIDs: postIDs)
        let (loadedLikes, loadedCounts) = await (likes, counts)

        for postID in postIDs {
            social[postID] = PostSocial(
                likes: loadedLikes?[postID] ?? .none,
                commentCount: loadedCounts?[postID] ?? 0
            )
        }
    }
}

/// The social footer's numbers for one post, bundled so the feed carries
/// one dictionary rather than two that can disagree about which posts they
/// cover.
struct PostSocial: Equatable, Hashable, Sendable {
    let likes: LikeInfo
    let commentCount: Int

    static let none = PostSocial(likes: .none, commentCount: 0)
}
