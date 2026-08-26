import PhotosUI
import SwiftUI

/// "Edit profile" sheet. Lets the signed-in user update their photo,
/// display name, and bio. Handle/username editing stays deferred.
///
/// Drives off `ProfileEditViewModel` for state; on success, calls
/// `onSaved` so the parent `ProfileView` can re-fetch the profile and
/// dismiss this sheet.
struct ProfileEditView: View {
    @Bindable var viewModel: ProfileEditViewModel
    var onSaved: () -> Void
    var onCancel: () -> Void

    @FocusState private var focusedField: Field?
    @State private var pickedItem: PhotosPickerItem?
    /// The photo being positioned, if any.
    @State private var cropping: CroppablePhoto?
    @State private var pickedPreview: UIImage?

    private enum Field {
        case displayName
        case bio
    }

    private let bioLimit = 160

    var body: some View {
        NavigationStack {
            Screen {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    avatarRow

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

    /// Current (or freshly picked) avatar with a photo-library picker.
    /// The picked image is downscaled and JPEG-encoded immediately so the
    /// view-model only ever holds upload-ready bytes.
    private var avatarRow: some View {
        HStack(spacing: Theme.Spacing.lg) {
            if let pickedPreview {
                Image(uiImage: pickedPreview)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
            } else {
                AvatarBadge(
                    name: viewModel.displayName.isEmpty ? "?" : viewModel.displayName,
                    avatarURL: viewModel.currentAvatarURL,
                    size: 72
                )
            }

            PhotosPicker(selection: $pickedItem, matching: .images) {
                Text("Change photo")
                    .font(Theme.Font.callout.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
            }
            .accessibilityIdentifier("profile_edit_change_photo")

            Spacer()
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                // Straight to the cropper. What used to happen here — crop
                // centre-out and hope — is now the starting position
                // rather than the answer.
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else { return }
                cropping = CroppablePhoto(image: image)
            }
        }
        .sheet(item: $cropping) { photo in
            AvatarCropperView(
                image: photo.image,
                onCancel: { cropping = nil },
                onConfirm: { jpeg in
                    viewModel.selectedAvatarData = jpeg
                    pickedPreview = UIImage(data: jpeg)
                    cropping = nil
                    pickedItem = nil
                }
            )
            .presentationDetents([.large])
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

/// Periphery flags this as unused — it's reachable only from the
/// `#Preview` macro above, which periphery cannot statically resolve.
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

    func uploadAvatar(userID _: UUID, jpegData _: Data) async throws -> URL {
        URL(filePath: "/dev/null")
    }

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
}
