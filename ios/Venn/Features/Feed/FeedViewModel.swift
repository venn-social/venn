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
    enum State: Equatable {
        case loading
        case loaded([FeedPost])
        case error(ErrorReason)
    }

    /// UI-layer reason a feed load failed. View renders different copy
    /// per reason; everything outside `.offline` collapses to `.unknown`
    /// because the user can't act on the distinction.
    enum ErrorReason: Equatable {
        case offline
        case unknown
    }

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
            state = .error(reason(for: error))
        } catch {
            state = .error(.unknown)
        }
    }

    private func reason(for error: AppError) -> ErrorReason {
        switch error {
        case .network: .offline
        case .unauthorized, .validation, .rateLimited, .server, .unknown: .unknown
        }
    }
}
