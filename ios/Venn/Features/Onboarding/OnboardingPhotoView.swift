import PhotosUI
import SwiftUI

/// Step 2 of 2: optional profile photo. Mirrors the edit sheet's picker
/// (picked image is downscaled + JPEG-encoded immediately) with a big
/// preview circle as the hero. Skippable — a photo never blocks entry.
struct OnboardingPhotoView: View {
    @State var viewModel: OnboardingPhotoViewModel
    /// Called when the step finishes (uploaded or skipped).
    let onComplete: () -> Void

    @State private var pickedItem: PhotosPickerItem?
    @State private var pickedPreview: UIImage?
    /// The photo being positioned, if any.
    @State private var cropping: CroppablePhoto?

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Step 2 of 2")
                            .font(Theme.Font.caption.weight(.semibold))
                            .foregroundStyle(Theme.Color.textSecondary)
                        Text("Add a face to the name")
                            .font(Theme.Font.title)
                            .foregroundStyle(Theme.Color.textPrimary)
                        Text("Your photo shows up next to everything you log. You can always change it later.")
                            .font(Theme.Font.callout)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }

                    // Snapshot the preview before the picker label closure —
                    // it's nonisolated under strict concurrency and can't
                    // read @State directly.
                    let preview = pickedPreview
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $pickedItem, matching: .images) {
                            ZStack {
                                if let preview {
                                    Image(uiImage: preview)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 140, height: 140)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Theme.Color.surfaceStrong)
                                        .frame(width: 140, height: 140)
                                    Image(systemName: "camera")
                                        .font(Theme.Font.largeTitle)
                                        .foregroundStyle(Theme.Color.accent)
                                }
                            }
                        }
                        .accessibilityIdentifier("onboarding_photo_picker")
                        Spacer()
                    }

                    if viewModel.failed {
                        Text("Couldn't upload that photo. Try again — or skip and add one later.")
                            .font(Theme.Font.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    PrimaryButton(
                        title: "Continue",
                        isLoading: viewModel.state == .uploading,
                        isEnabled: viewModel.canContinue
                    ) {
                        Task {
                            await viewModel.submit()
                            if viewModel.state == .done {
                                onComplete()
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            viewModel.skip()
                            onComplete()
                        } label: {
                            Text("Skip for now")
                                .font(Theme.Font.callout.weight(.semibold))
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                        .accessibilityIdentifier("onboarding_photo_skip")
                        Spacer()
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xxxl)
            }
            .scrollContentBackground(.hidden)
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task {
                // Same cropper the edit screen uses. Choosing a photo is
                // one act, and it should not go differently depending on
                // which door you came in.
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
                    viewModel.selectedJPEG = jpeg
                    pickedPreview = UIImage(data: jpeg)
                    cropping = nil
                    pickedItem = nil
                }
            )
            .presentationDetents([.large])
        }
    }
}
