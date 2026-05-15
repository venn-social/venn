import SwiftUI

/// Top-level routing. Picks between the splash, the sign-in screen, and the
/// signed-in main app based on `AuthState.status`. Recreates the auth view-
/// model with the live `AuthService` only when the user is actually signed
/// out, so we don't construct it during the splash flash.
struct RootView: View {
    private static let launchSplashDuration: Duration = .seconds(2)

    @Environment(AuthState.self)
    private var authState
    @Environment(AppConfig.self)
    private var config
    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @State private var isShowingLaunchSplash = true

    var body: some View {
        ZStack {
            // Atmospheric gradient sits beneath everything, including the
            // tab bar and nav bar, so Liquid Glass surfaces refract it.
            // Splash covers the gradient during launch — no clash.
            GlassSkyBackground()

            if isShowingLaunchSplash {
                LaunchVideoSplashView()
                    .transition(.opacity)
            } else {
                appContent
                    .transition(.opacity)
            }
        }
        .task {
            await dismissLaunchSplash()
        }
    }

    @ViewBuilder private var appContent: some View {
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-authFlow") {
                routedContent
            } else {
                DesignPreviewView()
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
        case .signedIn:
            MainView()
        }
    }

    @MainActor
    private func dismissLaunchSplash() async {
        guard isShowingLaunchSplash else { return }
        if ProcessInfo.processInfo.arguments.contains("-skipLaunchSplash") {
            isShowingLaunchSplash = false
            return
        }

        try? await Task.sleep(for: Self.launchSplashDuration)
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            isShowingLaunchSplash = false
        }
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
        .environment(AppearanceSettings())
}
