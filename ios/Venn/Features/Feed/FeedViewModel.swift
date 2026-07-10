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

    private let service: any FeedServicing
    private let pageSize: Int

    init(service: any FeedServicing, pageSize: Int = 20) {
        self.service = service
        self.pageSize = pageSize
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
        } catch let error as AppError {
            if case .loaded = state { return }
            state = .error(LoadErrorReason(error))
        } catch {
            if case .loaded = state { return }
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
            state = .loaded(current + next.filter { !seen.contains($0.id) })
        } catch {
            // Stop paging rather than let the footer retrigger an error
            // loop; pull-to-refresh restarts pagination from the top.
            hasMore = false
        }
    }
}
