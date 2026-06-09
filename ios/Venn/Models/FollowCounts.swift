import Foundation

/// Follower / following counts for a profile, read from the `follows`
/// directed-edge table.
struct FollowCounts: Equatable {
    let followers: Int
    let following: Int

    static let zero = FollowCounts(followers: 0, following: 0)
}
