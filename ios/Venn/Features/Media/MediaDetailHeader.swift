import SwiftUI

/// Cover, title, and the one-line facts at the top of the media detail
/// screen.
///
/// Everything except `detail` comes from our own `media` row, so this
/// renders in full before — and regardless of whether — the provider
/// answers. `detail` only adds to it.
struct MediaDetailHeader: View {
    let media: Media
    let detail: MediaDetail
    /// Nil when the row was typed by hand: with no external identity there
    /// is nothing for the composer to de-duplicate against.
    var onLog: (() -> Void)?

    /// "2023 · Celine Song" — whichever of year / creator is present. Same
    /// line as `FeedRow`.
    private var metadata: String {
        [media.year.map(String.init), media.primaryCreator]
            .compactMap(\.self)
            .joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.lg) {
            MediaCoverTile(
                title: media.title,
                kind: media.kind,
                coverURL: media.coverURL,
                height: 180,
                cornerRadius: Theme.Radius.md
            )
            .frame(width: 120)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(media.title)
                    .font(Theme.Font.title2)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !metadata.isEmpty {
                    Text(metadata)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                facts

                if let onLog {
                    Button("Log this", action: onLog)
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.Color.accent)
                        .padding(.top, Theme.Spacing.sm)
                }
            }

            Spacer(minLength: 0)
        }
    }

    /// Runtime, page count, and rating — whichever the provider has. The
    /// three catalogs each carry a different subset, so this is a flow
    /// rather than a fixed row.
    private var facts: some View {
        HStack(spacing: Theme.Spacing.md) {
            if let runtime = detail.formattedRuntime {
                Text(runtime)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            if let rating = detail.rating {
                RatingLabel(value: rating)
            }
        }
        .padding(.top, Theme.Spacing.xxs)
    }
}

#Preview("With detail") {
    var detail = MediaDetail()
    detail.runtime = 106
    detail.rating = 7.8

    return MediaDetailHeader(
        media: Media(
            id: UUID(),
            kind: .movie,
            title: "Past Lives",
            year: 2023,
            primaryCreator: "Celine Song",
            coverURL: nil,
            externalID: "666277",
            externalSource: .tmdb,
            createdAt: .now
        ),
        detail: detail
    ) {}
        .padding(Theme.Spacing.lg)
}

#Preview("Bare row") {
    MediaDetailHeader(
        media: Media(
            id: UUID(),
            kind: .book,
            title: "Piranesi",
            year: 2020,
            primaryCreator: "Susanna Clarke",
            coverURL: nil,
            externalID: nil,
            externalSource: nil,
            createdAt: .now
        ),
        detail: .empty
    )
    .padding(Theme.Spacing.lg)
}
