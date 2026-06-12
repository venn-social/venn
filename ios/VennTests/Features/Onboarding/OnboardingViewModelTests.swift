import Foundation
import Testing
@testable import Venn

@MainActor
struct OnboardingViewModelTests {
    @Test
    func cannotSubmitEmptyUsername() {
        let viewModel = makeViewModel()
        #expect(viewModel.canSubmit == false)
        viewModel.username = "   "
        #expect(viewModel.canSubmit == false)
    }

    @Test
    func validUsernameCreatesProfileAndCompletes() async {
        let service = FakeOnboardingService()
        let viewModel = makeViewModel(service: service)
        viewModel.username = "  Ada_Lovelace  "
        viewModel.displayName = "Ada Lovelace"

        await viewModel.submit()

        #expect(viewModel.state == .done)
        // Handle is normalized (trimmed + lowercased) before it hits the DB.
        #expect(service.createdUsernames == ["ada_lovelace"])
        #expect(service.createdDisplayNames == ["Ada Lovelace"])
    }

    @Test
    func emptyDisplayNameIsSentAsNil() async {
        let service = FakeOnboardingService()
        let viewModel = makeViewModel(service: service)
        viewModel.username = "ada"
        viewModel.displayName = "   "

        await viewModel.submit()

        #expect(viewModel.state == .done)
        #expect(service.createdDisplayNames == [nil])
    }

    @Test
    func shortUsernameFailsValidationWithoutNetworkCall() async {
        let service = FakeOnboardingService()
        let viewModel = makeViewModel(service: service)
        viewModel.username = "ab"

        await viewModel.submit()

        #expect(viewModel.errorReason == .usernameTooShort)
        #expect(viewModel.state == .editing)
        #expect(service.createdUsernames.isEmpty)
    }

    @Test
    func illegalCharactersFailValidation() async {
        let viewModel = makeViewModel()
        viewModel.username = "ada lovelace!"

        await viewModel.submit()

        #expect(viewModel.errorReason == .usernameInvalidCharacters)
    }

    @Test
    func overlongDisplayNameFailsValidation() async {
        let viewModel = makeViewModel()
        viewModel.username = "ada"
        viewModel.displayName = String(repeating: "a", count: 41)

        await viewModel.submit()

        #expect(viewModel.errorReason == .displayNameTooLong)
        #expect(viewModel.state == .editing)
    }

    @Test
    func takenUsernameSurfacesInlineAndReturnsToEditing() async {
        let service = FakeOnboardingService()
        service.createResult = .failure(UsernameTakenError())
        let viewModel = makeViewModel(service: service)
        viewModel.username = "maya"

        await viewModel.submit()

        #expect(viewModel.errorReason == .usernameTaken)
        #expect(viewModel.state == .editing)
    }

    @Test
    func networkFailureMapsToOffline() async {
        let service = FakeOnboardingService()
        service.createResult = .failure(AppError.network)
        let viewModel = makeViewModel(service: service)
        viewModel.username = "ada"

        await viewModel.submit()

        #expect(viewModel.errorReason == .offline)
        #expect(viewModel.state == .editing)
    }

    @Test
    func resubmitAfterTakenClearsTheError() async {
        let service = FakeOnboardingService()
        service.createResult = .failure(UsernameTakenError())
        let viewModel = makeViewModel(service: service)
        viewModel.username = "maya"
        await viewModel.submit()
        #expect(viewModel.errorReason == .usernameTaken)

        service.createResult = .success(())
        viewModel.username = "maya2"
        await viewModel.submit()

        #expect(viewModel.errorReason == nil)
        #expect(viewModel.state == .done)
    }

    // MARK: - Helpers

    private func makeViewModel(
        service: FakeOnboardingService = FakeOnboardingService()
    ) -> OnboardingViewModel {
        OnboardingViewModel(userID: UUID(), service: service)
    }
}

// MARK: - Fake

final class FakeOnboardingService: OnboardingServicing, @unchecked Sendable {
    var hasProfileResult: Result<Bool, Error> = .success(false)
    var createResult: Result<Void, Error> = .success(())
    private(set) var createdUsernames: [String] = []
    private(set) var createdDisplayNames: [String?] = []

    func hasProfile(userID _: UUID) async throws -> Bool {
        try hasProfileResult.get()
    }

    func createProfile(userID _: UUID, username: String, displayName: String?) async throws {
        createdUsernames.append(username)
        createdDisplayNames.append(displayName)
        try createResult.get()
    }
}
