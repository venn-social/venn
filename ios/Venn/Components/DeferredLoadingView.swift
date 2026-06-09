import SwiftUI

/// Lightweight section loader: holds an empty placeholder for a short delay,
/// then reveals a small spinner with an optional caption. Deferring prevents
/// the spinner flashing in and out when a `.loading` state resolves in under
/// ~300 ms — the brief flicker reads as jank, not feedback.
///
/// This is the loader for *sections* of a screen (a tab's data fetch). The
/// branded launch video is reserved for the full-screen startup splash
/// (`LaunchVideoSplashView`).
struct DeferredLoadingView: View {
    let caption: LocalizedStringKey?
    let delay: Duration

    @State private var shouldShow = false

    init(caption: LocalizedStringKey? = nil, delay: Duration = .milliseconds(300)) {
        self.caption = caption
        self.delay = delay
    }

    var body: some View {
        ZStack {
            if shouldShow {
                spinner
                    .transition(.opacity)
            } else {
                // Transparent placeholder that still occupies the full
                // frame so layout doesn't jump when the spinner fades in.
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                shouldShow = true
            }
        }
        .accessibilityIdentifier("deferred_loading_view")
    }

    private var spinner: some View {
        VStack(spacing: Theme.Spacing.md) {
            ProgressView()
                .tint(Theme.Color.textSecondary)
            if let caption {
                Text(caption)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("with caption") {
    DeferredLoadingView(caption: "Loading…")
}

#Preview("instant") {
    // Shows the loading state immediately for snapshot/visual verification.
    DeferredLoadingView(caption: "Loading…", delay: .zero)
}
