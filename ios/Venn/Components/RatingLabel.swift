import SwiftUI

/// Compact rating display — a single accent star plus the value, formatted
/// to one decimal place (e.g. "★ 4.5").
struct RatingLabel: View {
    let value: Double
    /// The number's colour. The star stays accent either way.
    ///
    /// Overridden to white where the label sits on artwork rather than on
    /// the page — a scrim is dark in both themes, so the token that follows
    /// the theme is the wrong one there.
    var valueColor: SwiftUI.Color = Theme.Color.textPrimary

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            Image(systemName: "star.fill")
                .font(.caption2)
                .foregroundStyle(Theme.Color.accent)
            Text(value.formatted(.number.precision(.fractionLength(1))))
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(valueColor)
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        RatingLabel(value: 4.5)
        RatingLabel(value: 8.7, valueColor: .white)
            .padding(Theme.Spacing.sm)
            .background(.black)
    }
    .padding(Theme.Spacing.lg)
}
