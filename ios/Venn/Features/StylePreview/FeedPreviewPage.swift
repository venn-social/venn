#if DEBUG
    import SwiftUI

    /// Feed page for the visual style preview: a header-less, image-forward
    /// stream of activity. DEBUG-only.
    struct FeedPreviewPage: View {
        var body: some View {
            NavigationStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 34) {
                        ForEach(StyleSampleData.feed) { activity in
                            FeedPreviewRow(activity: activity)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 48)
                }
                .stylePreviewSurface()
            }
        }
    }

    /// A single feed row: attribution, a large cover, the entry's title and
    /// metadata, an optional rating, and an optional note.
    private struct FeedPreviewRow: View {
        @Environment(\.colorScheme)
        private var scheme
        let activity: StyleActivity

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                attribution
                StyleCoverTile(
                    title: activity.entry.title,
                    kind: activity.entry.kind,
                    height: 200,
                    cornerRadius: 18
                )
                titleAndRating
                if let note = activity.note {
                    Text(note)
                        .font(.system(size: 15))
                        .foregroundStyle(StyleToken.inkSecondary(scheme))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
        }

        private var attribution: some View {
            HStack {
                Text("\(activity.author) \(activity.action)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(StyleToken.inkSecondary(scheme))
                Spacer()
                Text(activity.timestamp)
                    .font(.system(size: 13))
                    .foregroundStyle(StyleToken.inkTertiary(scheme))
            }
        }

        private var titleAndRating: some View {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.entry.title)
                        .font(.system(size: 21, weight: .semibold))
                        .tracking(-0.4)
                        .foregroundStyle(StyleToken.ink(scheme))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(activity.entry.creator) · \(activity.entry.year)")
                        .font(.system(size: 14))
                        .foregroundStyle(StyleToken.inkSecondary(scheme))
                }
                Spacer(minLength: 12)
                if let rating = activity.rating {
                    StyleRatingLabel(value: rating)
                }
            }
        }
    }

    #Preview("light") {
        ZStack { Theme.Color.background
            FeedPreviewPage()
        }
        .preferredColorScheme(.light)
    }

    #Preview("dark") {
        ZStack { Theme.Color.background
            FeedPreviewPage()
        }
        .preferredColorScheme(.dark)
    }
#endif
