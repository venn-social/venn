import Foundation
import Observation

/// Loads and exposes a profile row. Stateless beyond the `state` enum so
/// `ProfileView` can pattern-match on it directly.
///
/// `userID` is the profile to load — usually the current user, but the
/// same view-model is reused once profile-by-username navigation lands.
@MainActor
@Observable
final class ProfileViewModel {
    enum State: Equatable {
        case loading
        case loaded(UserProfile)
        case error(ErrorReason)
    }

    /// UI-layer reason a profile load failed. View renders different copy
    /// per reason; everything outside `.offline` collapses to `.unknown`
    /// because the user can't act on the distinction.
    enum ErrorReason: Equatable {
        case offline
        case unknown
    }

    private(set) var state: State = .loading
    let userID: UUID

    private let service: any ProfileServicing

    init(userID: UUID, service: any ProfileServicing) {
        self.userID = userID
        self.service = service
    }

    /// Fetches the profile and updates `state`. Safe to call again on
    /// retry — flips state back to `.loading` first.
    func load() async {
        state = .loading
        do {
            let profile = try await service.profile(for: userID)
            state = .loaded(profile)
        } catch let error as AppError {
            state = .error(reason(for: error))
        } catch {
            state = .error(.unknown)
        }
    }

    /// Translate a service-layer `AppError` into a UI-layer `ErrorReason`.
    /// Today only network failures get distinct copy; everything else is
    /// "something went wrong, retry." Add cases here as the view earns
    /// per-reason affordances.
    private func reason(for error: AppError) -> ErrorReason {
        switch error {
        case .network: .offline
        case .unauthorized, .validation, .rateLimited, .server, .unknown: .unknown
        }
    }
}
