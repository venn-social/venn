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
        let metrics = makeMetrics(logged: 5, saved: 2, rated: 3)
        let service = FakeProfileService()
        service.result = .success(profile)
        service.metricsResult = .success(metrics)
        let viewModel = ProfileViewModel(userID: profile.id, service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded(.init(profile: profile, metrics: metrics)))
        #expect(service.lastRequestedID == profile.id)
        #expect(service.lastMetricsID == profile.id)
    }

    @Test
    func loadFailureWithNonAppErrorFallsBackToUnknown() async {
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
    func metricsFailureAloneStillFailsTheLoad() async {
        // Profile + metrics fan out via `async let`; either failing
        // collapses the whole load to .error. This documents that —
        // we don't render a partial state.
        let service = FakeProfileService()
        service.result = .success(makeProfile(username: "ada"))
        service.metricsResult = .failure(AppError.network)
        let viewModel = ProfileViewModel(userID: .init(), service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func reloadAfterErrorReturnsToLoaded() async {
        struct Boom: Error {}
        let service = FakeProfileService()
        service.result = .failure(Boom())
        let viewModel = ProfileViewModel(userID: .init(), service: service)
        await viewModel.load()
        #expect(viewModel.state == .error(.unknown))

        service.result = .success(makeProfile(username: "ada"))
        service.metricsResult = .success(.empty)
        await viewModel.load()

        if case .loaded = viewModel.state {
            // ok
        } else {
            Issue.record("expected .loaded after successful reload, got \(viewModel.state)")
        }
    }

    // MARK: - helpers

    private func makeViewModel(failingWith error: any Error) -> ProfileViewModel {
        let service = FakeProfileService()
        service.result = .failure(error)
        service.metricsResult = .failure(error)
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

    private func makeMetrics(logged: Int, saved: Int, rated: Int) -> ProfileMetrics {
        ProfileMetrics(
            totalLogged: logged,
            totalSaved: saved,
            totalRated: rated,
            perCategory: [:]
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
    var metricsResult: Result<ProfileMetrics, Error> = .success(.empty)
    private(set) var lastRequestedID: UUID?
    private(set) var lastMetricsID: UUID?
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

    func metrics(for userID: UUID) async throws -> ProfileMetrics {
        lastMetricsID = userID
        return try metricsResult.get()
    }

    func watchlist(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        []
    }

    func collection(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        []
    }

    func removeFromLibrary(postID _: UUID) async throws {}

    private struct NotConfigured: Error {}
}
