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
                .containerBackground(for: .navigation) {
                    GlassSkyBackground()
                }
        }
        .task { await ensureLoaded() }
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
            // Pre-bootstrap (we don't have a session yet, somehow). Show
            // loading rather than crashing — RootView would normally have
            // routed away from here.
            LoadingView()
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
                    )

                    HStack(spacing: Theme.Spacing.sm) {
                        MetricTile(value: "\(metrics.totalLogged)", label: "logged")
                        MetricTile(value: "\(metrics.totalSaved)", label: "saved")
                        MetricTile(value: "\(metrics.totalRated)", label: "rated")
                    }

                    ProfileAppearanceSection()

                    ProfileLibrarySection(categories: Self.libraryCategories(from: metrics))

                    SecondaryButton(title: "Sign out") {
                        Task { await authState.signOut() }
                    }

                    versionFooter

                    Spacer(minLength: 0)
                }
                .padding(.vertical, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxxl * 2)
            }
            .scrollContentBackground(.hidden)
            .tracksGlassSkyParallax()
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

    private var versionFooter: some View {
        Text(verbatim: Self.versionString)
            .font(Theme.Font.footnote)
            .foregroundStyle(Theme.Color.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Theme.Spacing.md)
            .accessibilityIdentifier("profile_version_footer")
    }

    /// "venn 1.2.3 (4)" — short marketing version + build number from the
    /// app bundle. Falls back to a placeholder if the Info.plist values
    /// aren't readable (only happens in some preview contexts).
    /// Translate aggregate metrics into the per-row data the existing
    /// `ProfileLibrarySection` expects. Subtitle is "X watched · Y
    /// watchlist" when there's any activity, otherwise the empty-state
    /// copy carried by `ProfileLibraryCategory.empty`.
    private static func libraryCategories(from metrics: ProfileMetrics) -> [ProfileLibraryCategory] {
        ProfileLibraryCategory.empty.map { template in
            guard let kind = template.mediaKind,
                  let counts = metrics.perCategory[kind],
                  counts.watched + counts.watchlist > 0
            else { return template }
            return ProfileLibraryCategory(
                id: template.id,
                icon: template.icon,
                title: template.title,
                subtitle: "\(counts.watched) watched · \(counts.watchlist) watchlist",
                mediaKind: template.mediaKind,
                primaryActionTitle: template.primaryActionTitle,
                secondaryActionTitle: template.secondaryActionTitle
            )
        }
    }

    private static let versionString: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "venn \(version) (\(build))"
    }()

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
        .environment(AppearanceSettings())
}
