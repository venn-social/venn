import SwiftUI

/// Placeholder for the signed-in app shell. The real version lands in a
/// follow-up PR with a tab bar (feed, search, profile). For now this just
/// confirms the user is signed in and provides a sign-out affordance so the
/// auth round-trip is exercisable end-to-end.
struct MainView: View {
    @Environment(AuthState.self) private var authState
    @Environment(AppConfig.self) private var config

    var body: some View {
        Screen {
            VStack(spacing: Theme.Spacing.lg) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.Color.accent)
                Text(verbatim: "venn")
                    .font(Theme.Font.largeTitle)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(verbatim: config.appEnv.rawValue)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)

                Spacer().frame(height: Theme.Spacing.xl)

                Text("You're signed in. The real home screen lands in the next PR.")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .multilineTextAlignment(.center)

                SecondaryButton(title: "Sign out") {
                    Task { await authState.signOut() }
                }
            }
        }
    }
}

#Preview {
    let provider = SupabaseClientProvider.preview
    let state = AuthState(service: AuthService(client: provider.client))
    return MainView()
        .environment(AppConfig.preview)
        .environment(state)
}
