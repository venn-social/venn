import Foundation
import Testing
@testable import Venn

@MainActor
struct ProfileEditViewModelTests {
    @Test
    func initialStateIsEditingAndCannotSaveUntilChanged() {
        let viewModel = makeViewModel(displayName: "Ada", bio: "Hi")

        #expect(viewModel.state == .editing)
        #expect(viewModel.canSave == false)
    }

    @Test
    func canSaveBecomesTrueWhenAFieldChanges() {
        let viewModel = makeViewModel(displayName: "Ada", bio: "Hi")

        viewModel.displayName = "Ada Lovelace"

        #expect(viewModel.canSave)
    }

    @Test
    func saveTrimsAndForwardsTheNewValues() async {
        let userID = UUID()
        let service = FakeProfileService()
        let viewModel = ProfileEditViewModel(
            userID: userID,
            displayName: "Ada",
            bio: nil,
            service: service
        )

        viewModel.displayName = "  Ada Lovelace  "
        viewModel.bio = "Maths."

        await viewModel.save()

        #expect(viewModel.state == .saved)
        #expect(service.updateCalls.count == 1)
        #expect(service.updateCalls.first == .init(
            userID: userID,
            displayName: "Ada Lovelace",
            bio: "Maths."
        ))
    }

    @Test
    func pickingAnAvatarAloneEnablesSaveAndUploads() async {
        let service = FakeProfileService()
        let viewModel = ProfileEditViewModel(
            userID: UUID(),
            displayName: "Ada",
            bio: nil,
            service: service
        )
        #expect(viewModel.canSave == false)

        let jpeg = Data([0xFF, 0xD8, 0x01, 0x02])
        viewModel.selectedAvatarData = jpeg
        #expect(viewModel.canSave == true)

        await viewModel.save()

        #expect(viewModel.state == .saved)
        #expect(service.uploadedAvatarData == [jpeg])
    }

    @Test
    func failedAvatarUploadSurfacesSaveFailedWithoutTextUpdate() async {
        let service = FakeProfileService()
        service.uploadAvatarResult = .failure(AppError.server)
        let viewModel = ProfileEditViewModel(
            userID: UUID(),
            displayName: "Ada",
            bio: nil,
            service: service
        )
        viewModel.selectedAvatarData = Data([0xFF, 0xD8])

        await viewModel.save()

        #expect(viewModel.state == .error(.saveFailed))
        // Avatar upload runs first; the text update must not have fired.
        #expect(service.updateCalls.isEmpty)
    }

    @Test
    func emptyDisplayNameSendsNullToClearTheColumn() async {
        let userID = UUID()
        let service = FakeProfileService()
        let viewModel = ProfileEditViewModel(
            userID: userID,
            displayName: "Ada",
            bio: "Hi",
            service: service
        )

        viewModel.displayName = "   "
        viewModel.bio = ""

        await viewModel.save()

        #expect(service.updateCalls.first == .init(
            userID: userID,
            displayName: nil,
            bio: nil
        ))
    }

    @Test
    func bioOver160CharsTransitionsToError() async {
        let viewModel = makeViewModel(displayName: "Ada", bio: nil)
        viewModel.bio = String(repeating: "a", count: 161)

        await viewModel.save()

        #expect(viewModel.state == .error(.invalidBio))
    }

    @Test
    func displayNameOver40CharsTransitionsToError() async {
        let viewModel = makeViewModel(displayName: nil, bio: nil)
        viewModel.displayName = String(repeating: "a", count: 41)

        await viewModel.save()

        #expect(viewModel.state == .error(.invalidDisplayName))
    }

    @Test
    func nonAppErrorFailureFallsBackToSaveFailed() async {
        // A raw Error (not an AppError) goes down the catch-all branch.
        struct Boom: Error {}
        let viewModel = makeViewModel(failingWith: Boom())
        viewModel.displayName = "Ada Lovelace"

        await viewModel.save()

        #expect(viewModel.state == .error(.saveFailed))
    }

    @Test
    func appErrorNetworkMapsToOffline() async {
        let viewModel = makeViewModel(failingWith: AppError.network)
        viewModel.displayName = "Ada Lovelace"

        await viewModel.save()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func appErrorRateLimitedMapsToSaveFailed() async {
        let viewModel = makeViewModel(failingWith: AppError.rateLimited)
        viewModel.displayName = "Ada Lovelace"

        await viewModel.save()

        #expect(viewModel.state == .error(.saveFailed))
    }

    @Test
    func appErrorValidationMapsToSaveFailed() async {
        let viewModel = makeViewModel(failingWith: AppError.validation("server says no"))
        viewModel.displayName = "Ada Lovelace"

        await viewModel.save()

        #expect(viewModel.state == .error(.saveFailed))
    }

    // MARK: - helpers

    private func makeViewModel(
        displayName: String?,
        bio: String?
    ) -> ProfileEditViewModel {
        ProfileEditViewModel(
            userID: .init(),
            displayName: displayName,
            bio: bio,
            service: FakeProfileService()
        )
    }

    /// Pre-loads the fake to fail on update with the given error so the
    /// AppError-mapping tests can stay one-line.
    private func makeViewModel(failingWith error: any Error) -> ProfileEditViewModel {
        let service = FakeProfileService()
        service.updateResult = .failure(error)
        return ProfileEditViewModel(
            userID: .init(),
            displayName: "Ada",
            bio: nil,
            service: service
        )
    }
}
