import SwiftUI

/// Compact rating display — a single accent star plus the value, formatted
/// to one decimal place (e.g. "★ 4.5").
struct RatingLabel: View {
    let value: Double

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(Theme.Color.accent)
            Text(value.formatted(.number.precision(.fractionLength(1))))
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)
        }
    }
}

#Preview {
    RatingLabel(value: 4.5)
        .padding(Theme.Spacing.lg)
}
