import SwiftUI

/// A feed post with its social controls: like and comment on the foot of
/// the artwork, and comments that open in place beneath it. Mirrors web's
/// `FeedPostCard.tsx` (CLAUDE.md rule 17).
///
/// This owns the whole card rather than sitting under one, because the
/// controls and the thread they open now live in two different places — the
/// controls on the cover, the thread below the post — and one view cannot
/// render into two parents. The expanded state belongs to whichever view
/// spans both, so it belongs here.
///
/// Comments load on first expand rather than with the feed: a feed screen
/// holds many posts and most threads are never opened, so fetching them all
/// up front would be the larger part of the cost, spent mostly on things
/// nobody reads. The permalink at `PostDetailView` still loads its own, and
/// is the only shareable address a conversation has.
struct FeedPostCardView: View {
    let feedPost: FeedPost
    let viewerID: UUID
    /// The server's view of the likes. Watched rather than read once, so
    /// the card reseeds itself when the counts arrive instead of being
    /// given a new identity — which would collapse an open thread and throw
    /// away the comments it had loaded, every time the feed refreshed.
    let info: LikeInfo
    let commentCount: Int
    let service: any SocialServicing
    var onLibraryAction: ((LibraryQuickAction) -> Void)?

    @State private var expanded = false
    @State private var commentsViewModel: PostDetailViewModel?

    private var shown: Int {
        if case let .loaded(comments) = commentsViewModel?.state {
            return comments.count
        }
        return commentCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            FeedRow(
                feedPost: feedPost,
                viewerID: viewerID,
                onLibraryAction: onLibraryAction
            ) {
                controls
            }

            if expanded, let commentsViewModel {
                Divider()
                CommentThreadView(
                    viewModel: commentsViewModel,
                    viewerID: viewerID,
                    postAuthorID: feedPost.post.authorID,
                    showsHeading: false
                )
            }
        }
    }

    /// Sized to the metadata line they share, not to body text.
    private var controls: some View {
        HStack(spacing: Theme.Spacing.md) {
            LikeButton(
                postID: feedPost.post.id,
                userID: viewerID,
                service: service,
                likedByMe: info.likedByMe,
                glyphSize: Theme.Font.footnote,
                unlikedTint: Self.onArtwork
            )

            Button(action: toggleComments) {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: "bubble.right")
                        .font(Theme.Font.footnote)
                    if shown > 0 {
                        Text(verbatim: "\(shown)")
                            .font(Theme.Font.caption)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(Self.onArtwork)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(shown == 1 ? "1 comment" : "\(shown) comments")
            .accessibilityHint(expanded ? "Hides the comments" : "Shows the comments")
        }
    }

    /// What secondary text weighs on a scrim. Not quite white: full white
    /// beside the white title would flatten the two into one line.
    private static let onArtwork = SwiftUI.Color.white.opacity(0.95)

    /// Open or close the thread, loading it the first time only.
    private func toggleComments() {
        expanded.toggle()
        guard expanded, commentsViewModel == nil else { return }

        let model = PostDetailViewModel(postID: feedPost.post.id, service: service)
        commentsViewModel = model
        Task { await model.load() }
    }
}
