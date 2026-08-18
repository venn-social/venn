import SwiftUI

/// Like button and comment count under a feed row, with the thread opening
/// in place. Mirrors web's `PostActions.tsx` in behaviour and copy
/// (CLAUDE.md rule 17).
///
/// Commenting used to mean pushing the permalink and coming back, which
/// loses your place in the feed and turns a reply into a trip. The comments
/// now expand under the post instead.
///
/// They load on first expand rather than with the feed: a feed screen holds
/// many posts and most threads are never opened, so fetching them all up
/// front would be the larger part of the cost, spent mostly on things
/// nobody reads.
///
/// Optimistic in both directions, unlike `FollowViewModel`: following has an
/// outcome the client can't predict (a private account turns a follow into a
/// pending request), but a like has exactly one possible result, so waiting
/// for the round trip would be latency for no information. Reverts on
/// failure.
struct PostActionsView: View {
    let postID: UUID
    let userID: UUID
    /// The server's view of the likes. Kept so the view can reseed itself
    /// when the counts arrive, instead of being replaced wholesale.
    let info: LikeInfo
    let commentCount: Int
    let service: any SocialServicing
    /// Set in the feed, where tapping the tally opens the thread in place.
    /// Nil on the permalink itself — the thread is already below, and
    /// expanding a second copy of it would be nonsense.
    let postDestination: FeedPost?

    @State private var expanded = false
    @State private var commentsViewModel: PostDetailViewModel?

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
        self.info = info
        self.commentCount = commentCount
        self.service = service
        self.postDestination = postDestination
        _liked = State(initialValue: info.likedByMe)
        _likeCount = State(initialValue: info.likeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            controls
                // Seed from the counts when they arrive, rather than
                // letting the feed hand this view a new identity to force
                // it. Re-identifying would rebuild the whole view — losing
                // an open thread and the comments it had already loaded —
                // every time the counts landed or the feed refreshed.
                .onChange(of: info) { _, latest in
                    liked = latest.likedByMe
                    likeCount = latest.likeCount
                }

            if expanded, let commentsViewModel, let postDestination {
                Divider()
                CommentThreadView(
                    viewModel: commentsViewModel,
                    viewerID: userID,
                    postAuthorID: postDestination.post.authorID,
                    showsHeading: false
                )
            }
        }
    }

    private var controls: some View {
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

            if postDestination != nil {
                Button(action: toggleComments) { commentTally }
                    .buttonStyle(.plain)
                    .accessibilityHint(expanded ? "Hides the comments" : "Shows the comments")
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

    /// Open or close the thread, loading it the first time only.
    private func toggleComments() {
        expanded.toggle()
        guard expanded, commentsViewModel == nil else { return }

        let model = PostDetailViewModel(postID: postID, service: service)
        commentsViewModel = model
        Task { await model.load() }
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
