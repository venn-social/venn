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
        #expect(service.updateCalls == [
            .init(userID: userID, displayName: "Ada Lovelace", bio: "Maths."),
        ])
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
    func serviceFailureTransitionsToSaveFailed() async {
        struct Boom: Error {}
        let service = FakeProfileService()
        service.updateResult = .failure(Boom())
        let viewModel = ProfileEditViewModel(
            userID: .init(),
            displayName: "Ada",
            bio: nil,
            service: service
        )
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
}
