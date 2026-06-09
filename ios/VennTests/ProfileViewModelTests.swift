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
        let counts = FollowCounts(followers: 12, following: 7)
        let service = FakeProfileService()
        service.result = .success(profile)
        service.followCountsResult = .success(counts)
        let viewModel = ProfileViewModel(userID: profile.id, service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded(
            .init(profile: profile, followCounts: counts, collection: [], watchlist: [])
        ))
        #expect(service.lastRequestedID == profile.id)
        #expect(service.lastFollowCountsID == profile.id)
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
    func followCountsFailureAloneStillFailsTheLoad() async {
        // Profile + counts + shelves fan out via `async let`; any failing
        // collapses the whole load to .error. We don't render partial state.
        let service = FakeProfileService()
        service.result = .success(makeProfile(username: "ada"))
        service.followCountsResult = .failure(AppError.network)
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
        service.followCountsResult = .failure(error)
        service.collectionResult = .failure(error)
        service.watchlistResult = .failure(error)
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
    var followCountsResult: Result<FollowCounts, Error> = .success(.zero)
    var collectionResult: Result<[Media], Error> = .success([])
    var watchlistResult: Result<[Media], Error> = .success([])
    private(set) var lastRequestedID: UUID?
    private(set) var lastFollowCountsID: UUID?
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

    func followCounts(for userID: UUID) async throws -> FollowCounts {
        lastFollowCountsID = userID
        return try followCountsResult.get()
    }

    func shelf(_ shelf: ProfileShelf, for _: UUID, limit _: Int) async throws -> [Media] {
        switch shelf {
        case .collection: try collectionResult.get()
        case .watchlist: try watchlistResult.get()
        }
    }

    private struct NotConfigured: Error {}
}
