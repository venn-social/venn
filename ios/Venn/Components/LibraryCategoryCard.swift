import SwiftUI

/// Profile library entry point. Each category exposes the two core routes:
/// the user's aspirational list and their completed history.
struct LibraryCategoryCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var primaryActionTitle = "Watchlist"
    var secondaryActionTitle = "Data Room"

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: icon)
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(Theme.Color.surfaceStrong, in: .rect(cornerRadius: Theme.Radius.sm))

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(verbatim: title)
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(verbatim: subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(Theme.Font.caption.weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.sm)

            Divider()
                .padding(.leading, 64)

            HStack(spacing: Theme.Spacing.sm) {
                actionPill(primaryActionTitle)
                actionPill(secondaryActionTitle)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
        }
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Color.separator, lineWidth: 0.5)
        }
    }

    private func actionPill(_ title: String) -> some View {
        Text(verbatim: title)
            .font(Theme.Font.caption.weight(.semibold))
            .foregroundStyle(Theme.Color.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 34)
            .background(Theme.Color.surfaceStrong, in: .capsule)
    }
}

#Preview {
    LibraryCategoryCard(
        icon: "film",
        title: "Movies",
        subtitle: "42 watched · 12 watchlist"
    )
    .padding(Theme.Spacing.lg)
}
