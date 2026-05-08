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
    func loadFailureTransitionsToError() async {
        struct Boom: Error {}
        let service = FakeProfileService()
        service.result = .failure(Boom())
        let viewModel = ProfileViewModel(userID: .init(), service: service)

        await viewModel.load()

        #expect(viewModel.state == .error)
    }

    @Test
    func reloadAfterErrorReturnsToLoading() async {
        struct Boom: Error {}
        let service = FakeProfileService()
        service.result = .failure(Boom())
        let viewModel = ProfileViewModel(userID: .init(), service: service)
        await viewModel.load()
        #expect(viewModel.state == .error)

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
    var result: Result<UserProfile, Error> = .failure(NotConfigured())
    var lastRequestedID: UUID?

    func profile(for userID: UUID) async throws -> UserProfile {
        lastRequestedID = userID
        return try result.get()
    }

    private struct NotConfigured: Error {}
}
