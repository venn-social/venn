import SwiftUI

/// "Edit profile" sheet. Lets the signed-in user update their display name
/// and bio. Handle/username editing and avatar upload are deferred to
/// follow-up PRs.
///
/// Drives off `ProfileEditViewModel` for state; on success, calls
/// `onSaved` so the parent `ProfileView` can re-fetch the profile and
/// dismiss this sheet.
struct ProfileEditView: View {
    @Bindable var viewModel: ProfileEditViewModel
    var onSaved: () -> Void
    var onCancel: () -> Void

    @FocusState private var focusedField: Field?

    private enum Field {
        case displayName
        case bio
    }

    private let bioLimit = 160

    var body: some View {
        NavigationStack {
            Screen {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    fieldGroup(label: "Display name") {
                        TextField("Your name", text: $viewModel.displayName)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .displayName)
                            .padding(Theme.Spacing.md)
                            .background(
                                Theme.Color.surface,
                                in: .rect(cornerRadius: Theme.Radius.md)
                            )
                            .accessibilityIdentifier("profile_edit_display_name")
                    }

                    fieldGroup(label: "Bio") {
                        VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                            TextField(
                                "A short bio",
                                text: $viewModel.bio,
                                axis: .vertical
                            )
                            .lineLimit(3...6)
                            .focused($focusedField, equals: .bio)
                            .padding(Theme.Spacing.md)
                            .background(
                                Theme.Color.surface,
                                in: .rect(cornerRadius: Theme.Radius.md)
                            )
                            .accessibilityIdentifier("profile_edit_bio")

                            Text(verbatim: "\(viewModel.bio.count) / \(bioLimit)")
                                .font(Theme.Font.caption)
                                .foregroundStyle(bioCountColor)
                                .accessibilityIdentifier("profile_edit_bio_count")
                        }
                    }

                    if case let .error(reason) = viewModel.state {
                        Text(errorMessage(for: reason))
                            .font(Theme.Font.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("profile_edit_error")
                    }

                    Spacer(minLength: 0)
                }
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .accessibilityIdentifier("profile_edit_cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        focusedField = nil
                        Task {
                            await viewModel.save()
                            if viewModel.state == .saved {
                                onSaved()
                            }
                        }
                    }
                    .disabled(!viewModel.canSave)
                    .accessibilityIdentifier("profile_edit_save")
                }
            }
        }
    }

    private func fieldGroup(
        label: LocalizedStringKey,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
            content()
        }
    }

    private var bioCountColor: Color {
        viewModel.bio.count > bioLimit ? .red : Theme.Color.textSecondary
    }

    private func errorMessage(
        for reason: ProfileEditViewModel.ErrorReason
    ) -> LocalizedStringKey {
        switch reason {
        case .invalidDisplayName: "Display name must be 1–40 characters."
        case .invalidBio: "Bio must be 160 characters or fewer."
        case .offline: "You're offline. Check your connection and try again."
        case .saveFailed: "Couldn't save your changes. Please try again."
        }
    }
}

#Preview {
    ProfileEditView(
        viewModel: ProfileEditViewModel(
            userID: .init(),
            displayName: "Ada Lovelace",
            bio: "First programmer.",
            service: PreviewProfileService()
        ),
        onSaved: {},
        onCancel: {}
    )
}

private struct PreviewProfileService: ProfileServicing {
    func profile(for _: UUID) async throws -> UserProfile {
        UserProfile(
            id: .init(),
            username: "ada",
            displayName: "Ada Lovelace",
            avatarURL: nil,
            bio: "First programmer.",
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }

    func updateProfile(userID _: UUID, displayName _: String?, bio _: String?) async throws {}
}
