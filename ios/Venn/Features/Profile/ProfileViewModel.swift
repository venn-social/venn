import Foundation
import Observation

/// Bundle of everything `ProfileView` needs once a profile has loaded — the
/// row, the follow counts, and the Collection / Watchlist library items.
/// Carried by `ProfileViewModel.State.loaded` so the view renders the full
/// surface from a single state transition.
struct ProfileSnapshot: Equatable {
    let profile: UserProfile
    let followCounts: FollowCounts
    let collection: [LibraryItem]
    let watchlist: [LibraryItem]
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
    typealias State = LoadState<ProfileSnapshot>

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
            async let collection = service.collection(for: userID, kind: nil)
            async let watchlist = service.watchlist(for: userID, kind: nil)
            let snapshot = try await ProfileSnapshot(
                profile: profile,
                followCounts: followCounts,
                collection: collection,
                watchlist: watchlist
            )
            state = .loaded(snapshot)
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }

    /// Re-fetch just the follow counts and patch them into the loaded
    /// snapshot — used after a follow/unfollow so the numbers update
    /// without bouncing the whole screen through `.loading`. No-ops
    /// (keeping the stale counts) when not loaded or when the fetch fails.
    func refreshFollowCounts() async {
        guard case let .loaded(snapshot) = state,
              let counts = try? await service.followCounts(for: userID)
        else { return }
        state = .loaded(ProfileSnapshot(
            profile: snapshot.profile,
            followCounts: counts,
            collection: snapshot.collection,
            watchlist: snapshot.watchlist
        ))
    }
}
