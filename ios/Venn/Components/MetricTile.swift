import SwiftUI

/// Compact profile metric with a monospaced value and subdued label.
struct MetricTile: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Color.surfaceStrong, in: .rect(cornerRadius: Theme.Radius.sm))
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.sm) {
        MetricTile(value: "128", label: "watched")
        MetricTile(value: "34", label: "saved")
        MetricTile(value: "18", label: "overlaps")
    }
    .padding(Theme.Spacing.lg)
}
