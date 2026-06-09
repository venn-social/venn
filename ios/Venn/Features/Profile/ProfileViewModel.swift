import Foundation
import Observation

/// Bundle of everything `ProfileView` needs once a profile has loaded —
/// the row itself plus the aggregate metrics for the tiles + library
/// section. Carried by `ProfileViewModel.State.loaded` so the view
/// renders the full surface from a single state transition.
struct ProfileSnapshot: Equatable {
    let profile: UserProfile
    let followCounts: FollowCounts
    let collection: [Media]
    let watchlist: [Media]
}

/// Loads and exposes a profile row plus its aggregate metrics.
/// Stateless beyond the `state` enum so `ProfileView` can pattern-
/// match on it directly.
///
/// `userID` is the profile to load — usually the current user, but
/// the same view-model is reused once profile-by-username navigation
/// lands.
@MainActor
@Observable
final class ProfileViewModel {
    enum State: Equatable {
        case loading
        case loaded(ProfileSnapshot)
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

    /// Fetches the profile and its metrics in parallel and updates
    /// `state`. Safe to call again on retry — flips state back to
    /// `.loading` first.
    func load() async {
        state = .loading
        do {
            async let profile = service.profile(for: userID)
            async let followCounts = service.followCounts(for: userID)
            async let collection = service.shelf(.collection, for: userID, limit: 30)
            async let watchlist = service.shelf(.watchlist, for: userID, limit: 30)
            let snapshot = try await ProfileSnapshot(
                profile: profile,
                followCounts: followCounts,
                collection: collection,
                watchlist: watchlist
            )
            state = .loaded(snapshot)
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
