import SwiftUI

/// Top-level routing. Picks between the splash, the sign-in screen, and the
/// signed-in main app based on `AuthState.status`. Recreates the auth view-
/// model with the live `AuthService` only when the user is actually signed
/// out, so we don't construct it during the splash flash.
struct RootView: View {
    @Environment(AuthState.self) private var authState
    @Environment(AppConfig.self) private var config
    @Environment(SupabaseClientProvider.self) private var clientProvider

    var body: some View {
        switch authState.status {
        case .unknown:
            LoadingView(caption: "Loading…")
        case .signedOut:
            AuthView(viewModel: AuthViewModel(
                service: AuthService(client: clientProvider.client),
                redirectURL: config.authCallbackURL
            ))
        case .signedIn:
            MainView()
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
}
