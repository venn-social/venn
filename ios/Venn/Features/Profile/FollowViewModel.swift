import Foundation
import Observation

/// Drives the Follow / Requested / Following button on `PublicProfileView`.
///
/// Unfollowing (from `.following`) and cancelling a request (from
/// `.requested`) are both a delete, so they stay optimistic per the
/// data-flow rules in `docs/ARCHITECTURE.md`: the button flips immediately
/// and reverts if the write fails.
///
/// Starting a follow is different: whether it lands as `.requested` or
/// `.following` depends on the target's privacy, which this view-model
/// doesn't know ahead of the server's answer — so that path is NOT
/// optimistic. `isWorking` covers the round trip instead.
@MainActor
@Observable
final class FollowViewModel {
    enum State: Equatable {
        case notFollowing
        case requested
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
        let status = try? await service.followStatus(followerID: followerID, followeeID: followeeID)
        state = Self.state(for: status)
    }

    /// Re-entrant taps while a write is in flight are ignored.
    func toggle() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        switch state {
        case .following, .requested:
            await cancelOrUnfollow()
        case .notFollowing:
            await startFollowing()
        }
    }

    /// Delete is optimistic: flip to `.notFollowing`, write, revert on failure.
    private func cancelOrUnfollow() async {
        let original = state
        state = .notFollowing
        do {
            try await service.unfollow(followerID: followerID, followeeID: followeeID)
        } catch {
            state = original
        }
    }

    /// Not optimistic — the resulting state depends on the server's answer
    /// (public target → accepted instantly; private target → pending).
    private func startFollowing() async {
        do {
            let status = try await service.requestFollow(followerID: followerID, followeeID: followeeID)
            state = Self.state(for: status)
        } catch {
            state = .notFollowing
        }
    }

    private static func state(for status: FollowStatus?) -> State {
        switch status {
        case .none: .notFollowing
        case .pending: .requested
        case .accepted: .following
        }
    }
}
