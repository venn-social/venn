import SwiftUI

/// The brand button. Filled with the accent color, full-width, intended for
/// the primary call-to-action on a screen ("Sign in", "Post", "Follow").
/// Use `SecondaryButton` for non-primary actions.
///
/// `isLoading` swaps the title for a spinner without changing the button's
/// height — handy for sign-in / submit flows where a tap kicks off network
/// work.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var isLoading = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(Theme.Color.onAccent)
                }
            }
            .font(Theme.Font.headline)
            .foregroundStyle(Theme.Color.onAccent)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.Gradient.overlap, in: .capsule)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .accessibilityIdentifier("primary_button")
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        PrimaryButton(title: "Continue") {}
        PrimaryButton(title: "Loading", isLoading: true) {}
        PrimaryButton(title: "Disabled", isEnabled: false) {}
    }
    .padding(Theme.Spacing.lg)
}
