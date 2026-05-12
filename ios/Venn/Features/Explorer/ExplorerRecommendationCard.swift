import SwiftUI

struct ExplorerRecommendationCard: View {
    let category: ExplorerCategory
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            HStack {
                Image(systemName: category.icon)
                    .font(Theme.Font.title3)
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Theme.Color.graphite, in: .rect(cornerRadius: Theme.Radius.sm))
                Spacer()
                Text("82% match")
                    .font(Theme.Font.caption.weight(.bold))
                    .foregroundStyle(Theme.Color.textPrimary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.surfaceStrong, in: .capsule)
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(Theme.Font.title3)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(detail)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            HStack(spacing: Theme.Spacing.sm) {
                PrimaryButton(title: "Save") {}
                SecondaryButton(title: "Seen it") {}
            }
        }
        .padding(Theme.Spacing.lg)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Color.separator, lineWidth: 0.5)
        }
    }
}

#Preview {
    ExplorerRecommendationCard(
        category: .movies,
        title: "Aftersun",
        detail: "Because you and Maya both logged soft heartbreak movies."
    )
    .padding(Theme.Spacing.lg)
}
