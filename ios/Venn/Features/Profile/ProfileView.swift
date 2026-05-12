import SwiftUI

/// Profile tab content. Loads the signed-in user's profile from Supabase and
/// renders identity, high-level stats, and category entry points.
struct ProfileView: View {
    @Environment(AuthState.self)
    private var authState
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var viewModel: ProfileViewModel?
    @State private var editViewModel: ProfileEditViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if case .loaded = viewModel?.state {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Edit") { presentEditSheet() }
                                .accessibilityIdentifier("profile_edit_button")
                        }
                    }
                }
                .sheet(
                    isPresented: Binding(
                        get: { editViewModel != nil },
                        set: { if !$0 { editViewModel = nil } }
                    )
                ) {
                    if let editViewModel {
                        ProfileEditView(
                            viewModel: editViewModel,
                            onSaved: {
                                self.editViewModel = nil
                                Task { await viewModel?.load() }
                            },
                            onCancel: { self.editViewModel = nil }
                        )
                    }
                }
        }
        .task { await ensureLoaded() }
    }

    private func presentEditSheet() {
        guard let viewModel,
              case let .loaded(profile) = viewModel.state
        else {
            return
        }
        editViewModel = ProfileEditViewModel(
            userID: profile.id,
            displayName: profile.displayName,
            bio: profile.bio,
            service: ProfileService(client: clientProvider.client)
        )
    }

    @ViewBuilder private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                LoadingView(caption: "Loading your profile…")
            case let .loaded(profile):
                loadedView(profile)
            case let .error(reason):
                errorView(reason: reason) { Task { await viewModel.load() } }
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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ProfileHeaderView(
                        name: profile.displayName ?? profile.username,
                        handle: profile.username,
                        bio: profile.bio
                    )

                    HStack(spacing: Theme.Spacing.sm) {
                        MetricTile(value: "0", label: "watched")
                        MetricTile(value: "0", label: "saved")
                        MetricTile(value: "0", label: "overlaps")
                    }

                    ProfileLibrarySection(categories: ProfileLibraryCategory.empty)

                    SecondaryButton(title: "Sign out") {
                        Task { await authState.signOut() }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxxl * 2)
            }
        }
    }

    private func errorView(
        reason: ProfileViewModel.ErrorReason,
        retry: @escaping () -> Void
    ) -> some View {
        EmptyStateView(
            systemImage: "exclamationmark.triangle",
            title: errorTitle(for: reason),
            message: errorMessage(for: reason),
            actionTitle: "Try again",
            action: retry
        )
    }

    private func errorTitle(for reason: ProfileViewModel.ErrorReason) -> LocalizedStringKey {
        switch reason {
        case .offline: "You're offline"
        case .unknown: "Couldn't load your profile"
        }
    }

    private func errorMessage(for reason: ProfileViewModel.ErrorReason) -> LocalizedStringKey {
        switch reason {
        case .offline: "Check your connection and try again."
        case .unknown: "Something went wrong. Please try again."
        }
    }

    private func ensureLoaded() async {
        if viewModel == nil, case let .signedIn(session) = authState.status {
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
