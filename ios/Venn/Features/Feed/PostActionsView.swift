import SwiftUI

/// Like button and comment count under a feed row. Mirrors web's
/// `PostActions.tsx` in behaviour and copy (CLAUDE.md rule 17).
///
/// Optimistic in both directions, unlike `FollowViewModel`: following has an
/// outcome the client can't predict (a private account turns a follow into a
/// pending request), but a like has exactly one possible result, so waiting
/// for the round trip would be latency for no information. Reverts on
/// failure.
struct PostActionsView: View {
    let postID: UUID
    let userID: UUID
    let commentCount: Int
    let service: any SocialServicing
    /// Set in the feed, where the comment count is the way through to the
    /// conversation. Nil on the permalink itself — the thread is already
    /// below, and a link back to the current screen is a dead end.
    let postDestination: FeedPost?

    @State private var liked: Bool
    @State private var likeCount: Int
    @State private var working = false

    init(
        postID: UUID,
        userID: UUID,
        info: LikeInfo,
        commentCount: Int,
        service: any SocialServicing,
        postDestination: FeedPost? = nil
    ) {
        self.postID = postID
        self.userID = userID
        self.commentCount = commentCount
        self.service = service
        self.postDestination = postDestination
        _liked = State(initialValue: info.likedByMe)
        _likeCount = State(initialValue: info.likeCount)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Button(action: toggleLike) {
                HStack(spacing: Theme.Spacing.xs) {
                    // Same heart either way — it fills rather than
                    // changing shape. Red, not accent: the accent already
                    // means "interactive", so tinting a like with it would
                    // make every heart read as a link.
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .foregroundStyle(liked ? Theme.Color.like : Theme.Color.textSecondary)
                    if likeCount > 0 {
                        Text(verbatim: "\(likeCount)")
                            .font(Theme.Font.footnote)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .monospacedDigit()
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(working)
            .accessibilityLabel(liked ? "Unlike this post" : "Like this post")

            if let postDestination {
                NavigationLink(value: postDestination) {
                    commentTally
                }
                .buttonStyle(.plain)
            } else {
                commentTally
            }

            Spacer()
        }
    }

    private var commentTally: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "bubble.right")
                .foregroundStyle(Theme.Color.textSecondary)
            if commentCount > 0 {
                Text(verbatim: "\(commentCount)")
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel(commentCount == 1 ? "1 comment" : "\(commentCount) comments")
    }

    private func toggleLike() {
        let wasLiked = liked
        let previousCount = likeCount

        liked = !wasLiked
        likeCount = wasLiked ? max(0, previousCount - 1) : previousCount + 1
        working = true

        Task {
            do {
                if wasLiked {
                    try await service.unlike(postID: postID, userID: userID)
                } else {
                    try await service.like(postID: postID, userID: userID)
                }
            } catch {
                liked = wasLiked
                likeCount = previousCount
            }
            working = false
        }
    }
}
