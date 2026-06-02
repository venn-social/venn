import SwiftUI

/// Single recommendation tile. Stays a thin presentational primitive —
/// takes already-formatted strings so the same shape works for real
/// media and for prototype/preview content.
struct ExplorerRecommendationCard: View {
    let category: ExplorerCategory
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack {
                Image(systemName: category.icon)
                    .font(Theme.Font.title3)
                    .foregroundStyle(Theme.Color.onAccent)
                    .frame(width: 46, height: 46)
                    .background(Theme.Color.graphite, in: .rect(cornerRadius: Theme.Radius.sm))
                Spacer()
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Theme.Font.title3)
                    .foregroundStyle(Theme.Color.textPrimary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(Theme.Font.body)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }

            HStack(spacing: Theme.Spacing.sm) {
                PrimaryButton(title: "Save") {}
                SecondaryButton(title: "Seen it") {}
            }
        }
        .padding(Theme.Spacing.lg)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Color.separator, lineWidth: 1.5)
        }
    }
}

extension ExplorerRecommendationCard {
    /// Build a card from a domain `Media`. Detail line is "year · creator"
    /// when both are present, or whichever single one we have.
    init(media: Media, category: ExplorerCategory) {
        self.init(
            category: category,
            title: media.title,
            detail: Self.detail(for: media)
        )
    }

    private static func detail(for media: Media) -> String {
        [media.year.map(String.init), media.primaryCreator]
            .compactMap(\.self)
            .joined(separator: " · ")
    }
}

#Preview {
    ExplorerRecommendationCard(
        category: .movies,
        title: "Aftersun",
        detail: "2022 · Charlotte Wells"
    )
    .padding(Theme.Spacing.lg)
}
