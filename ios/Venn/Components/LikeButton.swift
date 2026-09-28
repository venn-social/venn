import SwiftUI

/// A heart, and nothing else. Mirrors web's `LikeButton.tsx`.
///
/// The tally is gone deliberately, on both platforms. A count next to a
/// like is a scoreboard, and a scoreboard changes what people post; the one
/// thing the control has to say is whether *you* liked this, which the fill
/// says on its own.
///
/// Optimistic in both directions, unlike `FollowViewModel`: following has an
/// outcome the client can't predict — a private account turns a follow into
/// a pending request — but a like has exactly one possible result, so
/// waiting for the round trip would be latency for no information. Reverts
/// on failure.
struct LikeButton: View {
    let postID: UUID
    let userID: UUID
    let service: any SocialServicing
    /// The server's view. Watched rather than read once, so the button can
    /// reseed itself when the counts land instead of being replaced — being
    /// given a new identity would throw away an in-flight tap.
    let likedByMe: Bool
    /// Glyph size. Smaller on a cover than under a post.
    var glyphSize: Font = Theme.Font.callout
    /// The unliked heart's colour. Liked is always `Theme.Color.like`.
    ///
    /// Overridden to white where the button sits on artwork rather than on
    /// the page — a scrim is dark in both themes, so the token that follows
    /// the theme is the wrong one there.
    var unlikedTint: SwiftUI.Color = Theme.Color.textSecondary

    @State private var liked: Bool
    @State private var working = false

    init(
        postID: UUID,
        userID: UUID,
        service: any SocialServicing,
        likedByMe: Bool,
        glyphSize: Font = Theme.Font.callout,
        unlikedTint: SwiftUI.Color = Theme.Color.textSecondary
    ) {
        self.postID = postID
        self.userID = userID
        self.service = service
        self.likedByMe = likedByMe
        self.glyphSize = glyphSize
        self.unlikedTint = unlikedTint
        _liked = State(initialValue: likedByMe)
    }

    var body: some View {
        Button(action: toggle) {
            // Same heart either way — it fills rather than changing shape.
            // Red, not accent: the accent already means "interactive", so
            // tinting a like with it would make every heart read as a link.
            Image(systemName: liked ? "heart.fill" : "heart")
                .font(glyphSize)
                .foregroundStyle(liked ? Theme.Color.like : unlikedTint)
        }
        .buttonStyle(.plain)
        .disabled(working)
        .accessibilityLabel(liked ? "Unlike this post" : "Like this post")
        .onChange(of: likedByMe) { _, latest in liked = latest }
    }

    private func toggle() {
        guard !working else { return }
        let wasLiked = liked
        liked = !wasLiked
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
            }
            working = false
        }
    }
}
