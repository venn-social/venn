import SwiftUI

/// Account-settings sheet, opened from the gear icon on `ProfileView`.
/// The private-account toggle, and the way out.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var onDismiss: () -> Void

    @Environment(AuthState.self)
    private var authState

    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            Screen {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    privacyRow

                    languageRow

                    if case let .error(reason) = viewModel.state {
                        Text(errorMessage(for: reason))
                            .font(Theme.Font.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("settings_error")
                    }

                    Spacer(minLength: 0)

                    signOutRow
                }
                .padding(Theme.Spacing.lg)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                    }
                    .accessibilityIdentifier("settings_done")
                }
            }
        }
    }

    /// Last, and visually separated: it is the one control here that ends
    /// the session rather than adjusting it.
    ///
    /// Confirmed before acting, unlike web's. Signing out on a phone means
    /// waiting on an email to get back in, and the button sits a thumb's
    /// width from a toggle people open this sheet to flip.
    private var signOutRow: some View {
        Button("Sign out", role: .destructive) {
            confirmingSignOut = true
        }
        .font(Theme.Font.body.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("settings_sign_out")
        .confirmationDialog(
            "Sign out of venn?",
            isPresented: $confirmingSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                Task {
                    await authState.signOut()
                    onDismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need your email to sign back in.")
        }
    }

    /// Which language the catalog is searched in.
    ///
    /// The copy is careful on purpose. This does not translate the app, and
    /// it does not restate titles other people have already logged — those
    /// rows are shared. Promising more would be the kind of setting people
    /// toggle, see nothing change, and stop trusting.
    private var languageRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Search language")
                .font(Theme.Font.body.weight(.medium))
                .foregroundStyle(Theme.Color.textPrimary)

            Text(
                "What the catalog is searched in. Titles other people have "
                    + "already logged stay as they were."
            )
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.textSecondary)

            Picker("Search language", selection: languageBinding) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.Color.accent)
            .disabled(viewModel.state == .saving)
            .accessibilityIdentifier("settings_language_picker")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.md))
    }

    /// Routes through the view-model's optimistic write, like `privacyBinding`.
    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { viewModel.language },
            set: { newValue in
                Task { await viewModel.setLanguage(newValue) }
            }
        )
    }

    private var privacyRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Toggle(isOn: privacyBinding) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Private account")
                        .font(Theme.Font.body.weight(.medium))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(
                        "Only approved followers see your posts, shelves, and Venn overlap. " +
                            "Your name, handle, and follower counts stay visible to everyone."
                    )
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .tint(Theme.Color.accent)
            .disabled(viewModel.state == .saving)
            .accessibilityIdentifier("settings_private_toggle")
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.md))
    }

    /// A `Binding` that routes through the view-model's optimistic write
    /// rather than mutating state directly — `Toggle` needs a two-way
    /// binding, but the source of truth stays `viewModel.isPrivate`.
    private var privacyBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isPrivate },
            set: { newValue in
                Task { await viewModel.setPrivate(newValue) }
            }
        )
    }

    private func errorMessage(for reason: SettingsViewModel.ErrorReason) -> LocalizedStringKey {
        switch reason {
        case .offline: "You're offline. Check your connection and try again."
        case .saveFailed: "Couldn't save that change. Please try again."
        }
    }
}

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            userID: UUID(),
            isPrivate: false,
            service: PreviewSettingsService()
        )
    ) {}
        .environment(AuthState(service: AuthService(client: SupabaseClientProvider.preview.client)))
}

/// Periphery flags this as unused — it's reachable only from the
/// `#Preview` macro above, which periphery cannot statically resolve.
private struct PreviewSettingsService: ProfileServicing {
    func profile(for _: UUID) async throws -> UserProfile {
        UserProfile(
            id: .init(),
            username: "ada",
            displayName: "Ada",
            avatarURL: nil,
            bio: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    func updateProfile(userID _: UUID, displayName _: String?, bio _: String?) async throws {}
    func followCounts(for _: UUID) async throws -> FollowCounts {
        .zero
    }

    func updatePrivacy(userID _: UUID, isPrivate _: Bool) async throws {}

    func updateLanguage(userID _: UUID, language _: AppLanguage) async throws {}
    func watchlist(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        []
    }

    func collection(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        []
    }

    func removeFromLibrary(postID _: UUID) async throws {}
    func updateRating(postID _: UUID, action _: PostAction, rating _: Double?) async throws {}
    func reorderLibrary(postIDs _: [UUID]) async throws {}
    func uploadAvatar(userID _: UUID, jpegData _: Data) async throws -> URL {
        URL(filePath: "/dev/null")
    }
}
