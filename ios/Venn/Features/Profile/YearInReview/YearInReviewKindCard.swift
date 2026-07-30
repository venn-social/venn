import SwiftUI

/// One row per media kind on the Year in Review screen: consumed count,
/// average rating (if any), and the most-logged creator (if any). Uses the
/// same kind → tonal-color mapping as `MediaCoverTile`'s placeholder tile,
/// so "movie" reads as the same cool blue-gray here as everywhere else a
/// cover is missing.
struct YearInReviewKindCard: View {
    let stats: KindStats

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            iconTile
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verbatim: "\(stats.kind.displayName.capitalized)s")
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Color.textPrimary)
                if let topCreator = stats.topCreator {
                    Text(verbatim: "Most logged: \(topCreator)")
                        .font(Theme.Font.footnote)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: Theme.Spacing.sm)
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                Text(verbatim: "\(stats.consumedCount)")
                    .font(Theme.Font.title2)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .monospacedDigit()
                if let avgRating = stats.avgRating {
                    RatingLabel(value: avgRating)
                }
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.lg))
    }

    private var iconTile: some View {
        Image(systemName: stats.kind.systemImage)
            .font(Theme.Font.title3)
            .foregroundStyle(Theme.Color.coverGlyph)
            .frame(width: 44, height: 44)
            .background(tint, in: .rect(cornerRadius: Theme.Radius.md))
    }

    private var tint: SwiftUI.Color {
        switch stats.kind {
        case .movie: Theme.Color.coverMovie
        case .show: Theme.Color.coverShow
        case .book: Theme.Color.coverBook
        case .album: Theme.Color.coverAlbum
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        YearInReviewKindCard(stats: .init(
            kind: .movie,
            consumedCount: 34,
            savedCount: 6,
            ratedCount: 20,
            avgRating: 4.2,
            topCreator: "Denis Villeneuve",
            topCreatorCount: 4
        ))
        YearInReviewKindCard(stats: .init(
            kind: .album,
            consumedCount: 12,
            savedCount: 0,
            ratedCount: 0,
            avgRating: nil,
            topCreator: nil,
            topCreatorCount: nil
        ))
    }
    .padding(Theme.Spacing.lg)
}
