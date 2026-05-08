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
        case error
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
        } catch {
            state = .error
        }
    }
}
