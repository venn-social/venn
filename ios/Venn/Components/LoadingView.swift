import SwiftUI

/// Centered loading indicator with an optional caption. Use for full-screen
/// loading states (session restoration, initial fetch). For inline loading
/// inside a button, prefer `PrimaryButton`'s `isLoading` flag.
struct LoadingView: View {
    let caption: LocalizedStringKey?

    init(caption: LocalizedStringKey? = nil) {
        self.caption = caption
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.Color.accent)
            if let caption {
                Text(caption)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("loading_view")
    }
}

#Preview("plain") {
    LoadingView()
}

#Preview("with caption") {
    LoadingView(caption: "Loading your feed…")
}
