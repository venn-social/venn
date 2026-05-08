import SwiftUI

/// Tinted alternate to `PrimaryButton`. Same footprint, accent-tinted
/// background, accent-colored text — for secondary actions ("Cancel",
/// "Skip", "Log in instead").
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Color.accent)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    Theme.Color.accent.opacity(0.12),
                    in: .rect(cornerRadius: Theme.Radius.md)
                )
                .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityIdentifier("secondary_button")
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        SecondaryButton(title: "Cancel") {}
        SecondaryButton(title: "Disabled", isEnabled: false) {}
    }
    .padding(Theme.Spacing.lg)
}
