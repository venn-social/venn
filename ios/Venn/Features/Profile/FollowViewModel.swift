import Foundation
import Observation

/// Drives the Follow / Following button on `PublicProfileView`.
///
/// `toggle()` is optimistic per the data-flow rules in
/// `docs/ARCHITECTURE.md`: the button flips immediately and reverts if the
/// write fails. A failed `load()` falls back to `.notFollowing` rather
/// than hiding the button — `FollowService.follow` is idempotent, so the
/// worst case ("Follow" shown while already following) self-heals on tap.
@MainActor
@Observable
final class FollowViewModel {
    enum State: Equatable {
        case notFollowing
        case following
    }

    private(set) var state: State = .notFollowing
    private(set) var isWorking = false

    /// The signed-in user (the edge's follower side).
    let followerID: UUID
    /// The profile being viewed.
    let followeeID: UUID

    private let service: any FollowServicing

    init(followerID: UUID, followeeID: UUID, service: any FollowServicing) {
        self.followerID = followerID
        self.followeeID = followeeID
        self.service = service
    }

    func load() async {
        let following = await (try? service.isFollowing(
            followerID: followerID,
            followeeID: followeeID
        )) ?? false
        state = following ? .following : .notFollowing
    }

    /// Optimistically flip, write the edge, revert on failure. Re-entrant
    /// taps while a write is in flight are ignored.
    func toggle() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        let original = state
        state = original == .following ? .notFollowing : .following
        do {
            if original == .following {
                try await service.unfollow(followerID: followerID, followeeID: followeeID)
            } else {
                try await service.follow(followerID: followerID, followeeID: followeeID)
            }
        } catch {
            state = original
        }
    }
}
