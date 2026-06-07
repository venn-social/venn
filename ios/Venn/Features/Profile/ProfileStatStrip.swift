import SwiftUI

/// Evenly-weighted profile stats — logged / saved / rated — in a soft
/// container with hairline dividers. Replaces the boxed metric tiles with a
/// quieter, more minimal strip.
struct ProfileStatStrip: View {
    let logged: Int
    let saved: Int
    let rated: Int

    var body: some View {
        HStack(spacing: 0) {
            column(logged, "logged")
            divider
            column(saved, "saved")
            divider
            column(rated, "rated")
        }
        .padding(.vertical, Theme.Spacing.lg)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.lg))
    }

    private func column(_ value: Int, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: Theme.Spacing.xxs) {
            Text("\(value)")
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Color.separator)
            .frame(width: 1, height: 28)
    }
}

#Preview {
    ProfileStatStrip(logged: 128, saved: 34, rated: 19)
        .padding(Theme.Spacing.lg)
}
