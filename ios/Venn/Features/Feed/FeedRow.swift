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

            titleAndRating

            if let caption = feedPost.post.caption, !caption.isEmpty {
                Text(caption)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var attribution: some View {
        HStack {
            Text("\(authorName) \(feedPost.post.action.rawValue)")
                .font(Theme.Font.footnote.weight(.medium))
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
