import SwiftUI

#if DEBUG
    /// DEBUG-only harness that walks the two onboarding steps
    /// (username → photo) against in-memory stubs, so the flow can be
    /// previewed and UI-tested without a real session or network. Booted
    /// by the `-previewOnboarding` launch arg (see `RootView`).
    ///
    /// The stub username check treats `venn` as taken and everything else
    /// as free, so a UI test can exercise both the ✓ and ✗ states.
    struct OnboardingPreviewView: View {
        private enum Step: Equatable {
            case username
            case photo
            case done
        }

        @State private var step: Step = .username
        private let userID = UUID()

        var body: some View {
            switch step {
            case .username:
                OnboardingView(viewModel: OnboardingViewModel(
                    userID: userID,
                    service: StubOnboardingService(),
                    availabilityDebounce: .milliseconds(50)
                )) {
                    step = .photo
                }
            case .photo:
                OnboardingPhotoView(viewModel: OnboardingPhotoViewModel(
                    userID: userID,
                    service: StubProfileService()
                )) {
                    step = .done
                }
            case .done:
                Screen {
                    VStack(spacing: Theme.Spacing.md) {
                        VennMark(size: 72)
                        // Identifier on the Text, not the VStack: an id on
                        // the container merges children into one a11y
                        // element and hides this text from staticText queries.
                        Text("You're in")
                            .font(Theme.Font.title)
                            .foregroundStyle(Theme.Color.textPrimary)
                            .accessibilityIdentifier("onboarding_preview_done")
                    }
                }
            }
        }
    }

    /// In-memory onboarding stub. `venn` is taken; all else is free.
    private struct StubOnboardingService: OnboardingServicing {
        func hasProfile(userID _: UUID) async throws -> Bool {
            false
        }

        func isUsernameAvailable(_ username: String) async throws -> Bool {
            username != "venn"
        }

        func createProfile(userID _: UUID, username _: String, displayName _: String?) async throws {}
    }

    /// Minimal profile stub for the photo step — only `uploadAvatar` is
    /// exercised; the rest satisfy the protocol.
    private struct StubProfileService: ProfileServicing {
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

    #Preview {
        OnboardingPreviewView()
            .environment(SupabaseClientProvider.preview)
    }
#endif
