import SwiftUI

/// Like and comment tally under a post, on the permalink.
///
/// The feed no longer uses this: its controls moved onto the artwork, which
/// put them in a different parent from the thread they open, so
/// `FeedPostCardView` owns that arrangement instead. What is left here is
/// the permalink's own row, where the thread is already below and there is
/// nothing to expand.
struct PostActionsView: View {
    let postID: UUID
    let userID: UUID
    /// The server's view of the likes. Watched rather than read once, so
    /// the row reseeds itself when the counts arrive instead of being
    /// replaced wholesale.
    let info: LikeInfo
    let commentCount: Int
    let service: any SocialServicing

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            LikeButton(
                postID: postID,
                userID: userID,
                service: service,
                likedByMe: info.likedByMe
            )

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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(commentCount == 1 ? "1 comment" : "\(commentCount) comments")

            Spacer()
        }
    }
}
