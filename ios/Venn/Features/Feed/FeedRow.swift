import SwiftUI

/// A single feed entry in the refreshed, image-forward layout: attribution,
/// a large cover, the entry's title and metadata, an optional rating, and an
/// optional note. Renders a `FeedPost` (post + media + author) from real
/// data.
///
/// The cover and the title open the title's detail screen, matching web.
/// Every host therefore has to register `.navigationDestination(for:
/// Media.self)`; the row pushes a value, not a view.
struct FeedRow: View {
    let feedPost: FeedPost

    /// The signed-in user, so the cover can offer Log / Add to Watchlist.
    /// Nil when signed out; equal to the author on your own posts, where
    /// there is nothing to offer that you do not already have.
    var viewerID: UUID?

    /// Runs the chosen action. The row does not own a service — the host
    /// screen does — so it hands the choice back up.
    var onLibraryAction: ((LibraryQuickAction) -> Void)?

    private var showsLibraryMenu: Bool {
        guard let viewerID, onLibraryAction != nil else { return false }
        return viewerID != feedPost.author.id
    }

    private var authorName: String {
        feedPost.author.displayName ?? feedPost.author.username
    }

    /// "2023 · Celine Song" — whichever of year / creator is present.
    private var metadata: String {
        [feedPost.media.year.map(String.init), feedPost.media.primaryCreator]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            attribution

            NavigationLink(value: feedPost.media) {
                MediaCoverTile(
                    title: feedPost.media.title,
                    kind: feedPost.media.kind,
                    coverURL: feedPost.media.coverURL,
                    height: 200
                )
            }
            .buttonStyle(.plain)
            // Long-press rather than a visible control: web reveals its menu
            // on hover, which no touch device can do, so iOS uses the
            // gesture that already means "more options" here.
            .contextMenu {
                if showsLibraryMenu {
                    ForEach(LibraryQuickAction.allCases) { action in
                        Button(action.title, systemImage: action.systemImage) {
                            onLibraryAction?(action)
                        }
                    }
                }
            }

            titleAndRating

            if let caption = feedPost.post.caption, !caption.isEmpty {
                Text(caption)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// The name is a link to the profile; the verb after it is not. Accent
    /// is this design system's signal for "interactive", and until now the
    /// name read as the same grey as the verb — there was nothing to
    /// suggest it could be tapped, and on iOS it could not be.
    private var attribution: some View {
        HStack(spacing: Theme.Spacing.xs) {
            NavigationLink(value: feedPost.author) {
                Text(authorName)
                    .font(Theme.Font.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
            }
            .buttonStyle(.plain)

            Text(feedPost.post.action.rawValue)
                .font(Theme.Font.footnote)
                .foregroundStyle(Theme.Color.textSecondary)

            Spacer()
            Text(RelativeTime.short(from: feedPost.post.createdAt))
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private var titleAndRating: some View {
        HStack(alignment: .firstTextBaseline) {
            NavigationLink(value: feedPost.media) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(feedPost.media.title)
                        .font(Theme.Font.title3)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if !metadata.isEmpty {
                        Text(metadata)
                            .font(Theme.Font.footnote)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: Theme.Spacing.md)
            if let rating = feedPost.post.rating {
                RatingLabel(value: rating)
            }
        }
    }
}
