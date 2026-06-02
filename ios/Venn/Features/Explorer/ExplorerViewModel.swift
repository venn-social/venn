import Foundation
import Observation

/// Loads recent media for the selected category and exposes them through
/// a single `state` enum. `ExplorerView` pattern-matches on it the same
/// way `FeedView` does, and re-invokes `load(kind:)` when the user
/// switches the category picker.
@MainActor
@Observable
final class ExplorerViewModel {
    enum State: Equatable {
        case loading
        case loaded([Media])
        case error(ErrorReason)
    }

    /// UI-layer reason a load failed. View renders different copy per
    /// reason; everything outside `.offline` collapses to `.unknown`
    /// because the user can't act on the distinction.
    enum ErrorReason: Equatable {
        case offline
        case unknown
    }

    private(set) var state: State = .loading

    private let service: any ExplorerServicing
    private let limit: Int

    init(service: any ExplorerServicing, limit: Int = 20) {
        self.service = service
        self.limit = limit
    }

    /// Fetches recent media for `kind` and updates `state`. Safe to call
    /// again on category switch or retry — flips back to `.loading` first.
    func load(kind: MediaKind) async {
        state = .loading
        do {
            let media = try await service.recentMedia(kind: kind, limit: limit)
            state = .loaded(media)
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
