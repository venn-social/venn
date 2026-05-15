import SwiftUI

/// Holds an empty placeholder for a short delay before revealing
/// `LoadingView`. Prevents the spinner from flashing in and out when a
/// `.loading` state resolves in under ~300 ms — the brief flicker reads as
/// jank, not feedback.
///
/// Use this anywhere the underlying load might be very fast (cached
/// profile fetch, warm-session auth bootstrap). For loads that always
/// take a while (initial bundle, large processing job), prefer the raw
/// `LoadingView` so the user gets immediate feedback.
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
                LoadingView(caption: caption)
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
}

#Preview("with caption") {
    DeferredLoadingView(caption: "Loading…")
}

#Preview("instant") {
    // Shows the loading state immediately for snapshot/visual verification.
    DeferredLoadingView(caption: "Loading…", delay: .zero)
}
