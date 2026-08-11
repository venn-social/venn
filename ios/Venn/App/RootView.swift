import SwiftUI

/// Top-level routing. Picks between the splash, the sign-in screen, and the
/// signed-in main app based on `AuthState.status`. Recreates the auth view-
/// model with the live `AuthService` only when the user is actually signed
/// out, so we don't construct it during the splash flash.
struct RootView: View {
    /// Safety fallback. Splash normally dismisses on `LaunchVideoSplashView`
    /// `onCompletion` (when the launch video finishes — `venn-launch-light`
    /// is ~8.3s, `venn-launch-dark` is ~5s). This timer only fires if the
    /// video fails to load and the completion callback never arrives; set
    /// generously above the longest video's duration.
    private static let launchSplashFallbackDuration: Duration = .seconds(12)

    @Environment(AuthState.self)
    private var authState
    @Environment(AppConfig.self)
    private var config
    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @State private var isShowingLaunchSplash = true

    var body: some View {
        ZStack {
            // Flat, matching web. This used to be an atmospheric gradient
            // for Liquid Glass surfaces to refract; the two platforms now
            // share one background so they read as the same product side
            // by side.
            Theme.Color.background
                .ignoresSafeArea()

            if isShowingLaunchSplash {
                LaunchVideoSplashView(onCompletion: dismissLaunchSplash)
                    .transition(.opacity)
            } else {
                appContent
                    .transition(.opacity)
            }
        }
        .task {
            await waitForLaunchSplashFallback()
        }
    }

    /// True when any of the preview-shell launch args is present —
    /// `-designPreview` plus the tab-pinning variants the UI tests use.
    private static var wantsDesignPreview: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-designPreview")
            || arguments.contains("-previewExplorer")
            || arguments.contains("-previewProfile")
    }

    @ViewBuilder private var appContent: some View {
        #if DEBUG
            // DEBUG boots the real app (sign-in and all) — the team now
            // runs on real data. The preview shells are opt-in:
            //   -designPreview     three-tab shell with a synthetic session
            //   -previewStyle      static design-language reference
            //   -previewAuth       sign-in screen against a stub (no real
            //                      magic-link send, no email rate limit)
            //   -previewComposer   the log flow against a stub (no writes
            //                      to the shared remote DB)
            if ProcessInfo.processInfo.arguments.contains("-previewStyle") {
                StylePreviewShell()
            } else if ProcessInfo.processInfo.arguments.contains("-previewOnboarding") {
                OnboardingPreviewView()
            } else if ProcessInfo.processInfo.arguments.contains("-previewAuth") {
                AuthPreviewView()
            } else if ProcessInfo.processInfo.arguments.contains("-previewComposer") {
                ComposerPreviewView()
            } else if Self.wantsDesignPreview {
                DesignPreviewView()
            } else {
                routedContent
            }
        #else
            routedContent
        #endif
    }

    @ViewBuilder private var routedContent: some View {
        switch authState.status {
        case .unknown:
            DeferredLoadingView(caption: "Loading…")
        case .signedOut:
            AuthView(viewModel: AuthViewModel(
                service: AuthService(client: clientProvider.client),
                redirectURL: config.authCallbackURL
            ))
        case let .signedIn(session):
            // Gate guarantees a profiles row exists before MainView —
            // first sign-ins detour through username onboarding.
            OnboardingGate(userID: session.user.id)
        }
    }

    @MainActor
    private func dismissLaunchSplash() {
        guard isShowingLaunchSplash else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            isShowingLaunchSplash = false
        }
    }

    @MainActor
    private func waitForLaunchSplashFallback() async {
        guard isShowingLaunchSplash else { return }
        if ProcessInfo.processInfo.arguments.contains("-skipLaunchSplash") {
            isShowingLaunchSplash = false
            return
        }

        try? await Task.sleep(for: Self.launchSplashFallbackDuration)
        guard !Task.isCancelled else { return }
        dismissLaunchSplash()
    }
}

#Preview("signed out") {
    let provider = SupabaseClientProvider.preview
    let state = AuthState(service: AuthService(client: provider.client))
    state.status = .signedOut
    return RootView()
        .environment(AppConfig.preview)
        .environment(provider)
        .environment(state)
}
