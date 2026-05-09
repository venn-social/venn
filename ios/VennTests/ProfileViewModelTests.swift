import Foundation
import Testing
@testable import Venn

@MainActor
struct ProfileViewModelTests {
    @Test
    func initialStateIsLoading() {
        let viewModel = ProfileViewModel(
            userID: .init(),
            service: FakeProfileService()
        )
        #expect(viewModel.state == .loading)
    }

    @Test
    func loadSuccessTransitionsToLoaded() async {
        let profile = makeProfile(username: "ada")
        let service = FakeProfileService()
        service.result = .success(profile)
        let viewModel = ProfileViewModel(userID: profile.id, service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded(profile))
        #expect(service.lastRequestedID == profile.id)
    }

    @Test
    func loadFailureWithNonAppErrorFallsBackToUnknown() async {
        // A raw Error (not an AppError) goes down the catch-all branch.
        struct Boom: Error {}
        let viewModel = makeViewModel(failingWith: Boom())

        await viewModel.load()

        #expect(viewModel.state == .error(.unknown))
    }

    @Test
    func loadFailureWithAppErrorNetworkMapsToOffline() async {
        let viewModel = makeViewModel(failingWith: AppError.network)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func loadFailureWithAppErrorServerMapsToUnknown() async {
        let viewModel = makeViewModel(failingWith: AppError.server)

        await viewModel.load()

        #expect(viewModel.state == .error(.unknown))
    }

    @Test
    func reloadAfterErrorReturnsToLoading() async {
        struct Boom: Error {}
        let service = FakeProfileService()
        service.result = .failure(Boom())
        let viewModel = ProfileViewModel(userID: .init(), service: service)
        await viewModel.load()
        #expect(viewModel.state == .error(.unknown))

        // Switch the service to succeed and reload.
        service.result = .success(makeProfile(username: "ada"))
        await viewModel.load()

        if case .loaded = viewModel.state {
            // ok
        } else {
            Issue.record("expected .loaded after successful reload, got \(viewModel.state)")
        }
    }

    // MARK: - helpers

    /// Pre-loads the fake to fail with the given error so error-path tests
    /// don't have to repeat the setup boilerplate.
    private func makeViewModel(failingWith error: any Error) -> ProfileViewModel {
        let service = FakeProfileService()
        service.result = .failure(error)
        return ProfileViewModel(userID: .init(), service: service)
    }

    private func makeProfile(username: String) -> UserProfile {
        UserProfile(
            id: .init(),
            username: username,
            displayName: username.capitalized,
            avatarURL: nil,
            bio: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}

final class FakeProfileService: ProfileServicing, @unchecked Sendable {
    struct UpdateCall: Equatable {
        let userID: UUID
        let displayName: String?
        let bio: String?
    }

    var result: Result<UserProfile, Error> = .failure(NotConfigured())
    var updateResult: Result<Void, Error> = .success(())
    private(set) var lastRequestedID: UUID?
    private(set) var updateCalls: [UpdateCall] = []

    func profile(for userID: UUID) async throws -> UserProfile {
        lastRequestedID = userID
        return try result.get()
    }

    func updateProfile(
        userID: UUID,
        displayName: String?,
        bio: String?
    ) async throws {
        updateCalls.append(.init(userID: userID, displayName: displayName, bio: bio))
        try updateResult.get()
    }

    private struct NotConfigured: Error {}
}
