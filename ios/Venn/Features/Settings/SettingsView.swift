import SwiftUI

/// Account-settings sheet, opened from the gear icon on `ProfileView`.
/// One row today: the private-account toggle.
struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Screen {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    privacyRow

                    if case let .error(reason) = viewModel.state {
                        Text(errorMessage(for: reason))
                            .font(Theme.Font.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("settings_error")
                    }

                    Spacer(minLength: 0)
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
    func watchlist(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        []
    }

    func collection(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        []
    }

    func removeFromLibrary(postID _: UUID) async throws {}
    func uploadAvatar(userID _: UUID, jpegData _: Data) async throws -> URL {
        URL(filePath: "/dev/null")
    }
}
