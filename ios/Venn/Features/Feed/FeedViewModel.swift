import Foundation
import Observation

/// Loads recent posts and exposes them through a single `state` enum.
/// `FeedView` pattern-matches on it directly (loading / loaded / error)
/// the same way `ProfileViewModel` does — keeps the view free of
/// imperative `if/else` over an async load.
///
/// Today this is a global feed (whatever `FeedService.recentPosts`
/// returns). When the follow graph is the source of truth, the model's
/// API stays the same; only the service implementation changes.
@MainActor
@Observable
final class FeedViewModel {
    typealias State = LoadState<[FeedPost]>

    private(set) var state: State = .loading

    private let service: any FeedServicing
    private let limit: Int

    init(service: any FeedServicing, limit: Int = 20) {
        self.service = service
        self.limit = limit
    }

    /// Fetches recent posts and updates `state`. Safe to call again on
    /// retry — flips state back to `.loading` first.
    func load() async {
        state = .loading
        do {
            let posts = try await service.recentPosts(limit: limit)
            state = .loaded(posts)
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }
}
