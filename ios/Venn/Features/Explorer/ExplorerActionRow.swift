import SwiftUI

struct ExplorerActionRow: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.graphite)
                .frame(width: 42, height: 42)
                .vennGlass(.regular, in: .rect(cornerRadius: Theme.Radius.sm))

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(detail)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Color.separator, lineWidth: 1.5)
        }
    }
}

#Preview {
    ExplorerActionRow(
        icon: "bookmark",
        title: "Save to watchlist",
        detail: "A softer maybe list for later."
    )
    .padding(Theme.Spacing.lg)
}
