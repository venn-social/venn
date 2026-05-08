import SwiftUI

/// Profile tab content. Loads the signed-in user's profile from Supabase
/// and renders header + VennOverlap (solo, since this PR only handles the
/// own-profile case). Other-user profiles with the pair overlap come in a
/// follow-up PR once profile-by-username navigation lands.
struct ProfileView: View {
    @Environment(AuthState.self)
    private var authState
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var viewModel: ProfileViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task { await ensureLoaded() }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                LoadingView(caption: "Loading your profile…")
            case .loaded(let profile):
                loadedView(profile)
            case .error:
                errorView(retry: { Task { await viewModel.load() } })
            }
        } else {
            // Pre-bootstrap (we don't have a session yet, somehow). Show
            // loading rather than crashing — RootView would normally have
            // routed away from here.
            LoadingView()
        }
    }

    private func loadedView(_ profile: UserProfile) -> some View {
        Screen {
            VStack(spacing: Theme.Spacing.xl) {
                header(profile)

                VennOverlap(mode: .solo(.init(
                    label: "Things you've logged",
                    count: 0
                )))

                SecondaryButton(title: "Sign out") {
                    Task { await authState.signOut() }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func header(_ profile: UserProfile) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(Theme.Color.surface)
                .frame(width: 96, height: 96)
                .overlay(
                    Text(verbatim: avatarInitial(profile))
                        .font(Theme.Font.title.weight(.bold))
                        .foregroundStyle(Theme.Color.textSecondary)
                )

            Text(verbatim: profile.displayName ?? profile.username)
                .font(Theme.Font.title2)
                .foregroundStyle(Theme.Color.textPrimary)

            Text(verbatim: "@\(profile.username)")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)

            if let bio = profile.bio, !bio.isEmpty {
                Text(verbatim: bio)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.xs)
            }
        }
    }

    private func errorView(retry: @escaping () -> Void) -> some View {
        EmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: "Couldn't load your profile",
            message: "Check your connection and try again.",
            actionTitle: "Try again",
            action: retry
        )
    }

    /// First letter of the display name (or handle), uppercased. Used as a
    /// placeholder until avatar uploads land.
    private func avatarInitial(_ profile: UserProfile) -> String {
        let source = profile.displayName ?? profile.username
        return source.first.map { String($0).uppercased() } ?? "?"
    }

    private func ensureLoaded() async {
        if viewModel == nil, case .signedIn(let session) = authState.status {
            let viewModel = ProfileViewModel(
                userID: session.user.id,
                service: ProfileService(client: clientProvider.client)
            )
            self.viewModel = viewModel
            await viewModel.load()
        }
    }
}

#Preview("loaded") {
    let provider = SupabaseClientProvider.preview
    let state = AuthState(service: AuthService(client: provider.client))
    return ProfileView()
        .environment(state)
        .environment(provider)
}
