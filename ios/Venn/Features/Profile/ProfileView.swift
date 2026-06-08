import SwiftUI

/// Profile tab content. Loads the signed-in user's profile from Supabase and
/// renders a minimal identity block, high-level stats, and a gallery of
/// recently-logged media — matching the refreshed, image-forward design.
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
                .toolbar(.hidden, for: .navigationBar)
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
                .containerBackground(for: .navigation) {
                    GlassSkyBackground()
                }
        }
        .task { await ensureLoaded() }
    }

    @ViewBuilder private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading your profile…")
            case let .loaded(snapshot):
                loadedView(snapshot)
            case let .error(reason):
                errorView(reason: reason) { Task { await viewModel.load() } }
            }
        } else {
            // Pre-bootstrap (no session yet). Show loading rather than
            // crashing — RootView would normally have routed away from here.
            DeferredLoadingView()
        }
    }

    private func loadedView(_ snapshot: ProfileSnapshot) -> some View {
        let profile = snapshot.profile
        let metrics = snapshot.metrics
        return Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ProfileHeaderView(
                        name: profile.displayName ?? profile.username,
                        handle: profile.username,
                        bio: profile.bio
                    ) { presentEditSheet() }

                    ProfileStatStrip(
                        logged: metrics.totalLogged,
                        saved: metrics.totalSaved,
                        rated: metrics.totalRated
                    )

                    recentlyLogged(snapshot.recentEntries)

                    SecondaryButton(title: "Sign out") {
                        Task { await authState.signOut() }
                    }
                }
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .scrollContentBackground(.hidden)
            .tracksGlassSkyParallax()
        }
    }

    private func recentlyLogged(_ entries: [Media]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recently logged")
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)

            if entries.isEmpty {
                Text("Nothing logged yet.")
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)
            } else {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: Theme.Spacing.md),
                        count: 3
                    ),
                    spacing: Theme.Spacing.md
                ) {
                    ForEach(entries) { media in
                        MediaCoverTile(
                            title: media.title,
                            kind: media.kind,
                            height: 120,
                            cornerRadius: Theme.Radius.md
                        )
                    }
                }
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

    private func presentEditSheet() {
        guard let viewModel,
              case let .loaded(snapshot) = viewModel.state
        else {
            return
        }
        let profile = snapshot.profile
        editViewModel = ProfileEditViewModel(
            userID: profile.id,
            displayName: profile.displayName,
            bio: profile.bio,
            service: ProfileService(client: clientProvider.client)
        )
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
