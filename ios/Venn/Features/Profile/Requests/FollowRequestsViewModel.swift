import Foundation
import Observation

/// Drives `FollowRequestsView`: the signed-in user's pending follow
/// requests, with optimistic accept/reject. Only meaningful for the
/// signed-in user's own id (see `FollowServicing.pendingRequests`).
@MainActor
@Observable
final class FollowRequestsViewModel {
    typealias State = LoadState<[UserProfile]>

    private(set) var state: State = .loading
    private(set) var respondingTo: Set<UUID> = []

    let userID: UUID
    private let service: any FollowServicing

    init(userID: UUID, service: any FollowServicing) {
        self.userID = userID
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            let requests = try await service.pendingRequests(for: userID, limit: 50)
            state = .loaded(requests)
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }

    /// Accept or reject one request. Optimistically removes it from the
    /// list; reverts (via reload) if the server call fails.
    func respond(to requester: UserProfile, accept: Bool) async {
        guard case var .loaded(requests) = state, !respondingTo.contains(requester.id) else { return }
        respondingTo.insert(requester.id)
        requests.removeAll { $0.id == requester.id }
        state = .loaded(requests)
        do {
            try await service.respondToRequest(followerID: requester.id, followeeID: userID, accept: accept)
        } catch {
            await load()
        }
        respondingTo.remove(requester.id)
    }
}
