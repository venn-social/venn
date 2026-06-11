import Foundation
import Testing
@testable import Venn

@MainActor
struct FollowViewModelTests {
    @Test
    func loadMapsFollowingEdgeToFollowingState() async {
        let service = FakeFollowService()
        service.isFollowingResult = .success(true)
        let viewModel = makeViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .following)
    }

    @Test
    func loadMapsMissingEdgeToNotFollowing() async {
        let service = FakeFollowService()
        service.isFollowingResult = .success(false)
        let viewModel = makeViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .notFollowing)
    }

    @Test
    func loadFailureFallsBackToNotFollowing() async {
        // Deliberate: follow() is idempotent, so showing "Follow" when the
        // check failed self-heals on tap instead of hiding the button.
        let service = FakeFollowService()
        service.isFollowingResult = .failure(AppError.network)
        let viewModel = makeViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .notFollowing)
    }

    @Test
    func toggleFromNotFollowingCallsFollowAndLandsOnFollowing() async {
        let service = FakeFollowService()
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .following)
        #expect(service.followCalls == 1)
        #expect(service.unfollowCalls == 0)
    }

    @Test
    func toggleFromFollowingCallsUnfollowAndLandsOnNotFollowing() async {
        let service = FakeFollowService()
        service.isFollowingResult = .success(true)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .notFollowing)
        #expect(service.unfollowCalls == 1)
    }

    @Test
    func failedFollowRevertsTheOptimisticFlip() async {
        let service = FakeFollowService()
        service.followResult = .failure(AppError.network)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .notFollowing)
    }

    @Test
    func failedUnfollowRevertsTheOptimisticFlip() async {
        let service = FakeFollowService()
        service.isFollowingResult = .success(true)
        service.unfollowResult = .failure(AppError.server)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .following)
    }

    // MARK: - Helpers

    private func makeViewModel(service: FakeFollowService) -> FollowViewModel {
        FollowViewModel(followerID: UUID(), followeeID: UUID(), service: service)
    }
}

// MARK: - Fake

final class FakeFollowService: FollowServicing, @unchecked Sendable {
    var isFollowingResult: Result<Bool, Error> = .success(false)
    var followResult: Result<Void, Error> = .success(())
    var unfollowResult: Result<Void, Error> = .success(())
    var followersResult: Result<[UserProfile], Error> = .success([])
    var followingResult: Result<[UserProfile], Error> = .success([])
    private(set) var followCalls = 0
    private(set) var unfollowCalls = 0

    func isFollowing(followerID _: UUID, followeeID _: UUID) async throws -> Bool {
        try isFollowingResult.get()
    }

    func follow(followerID _: UUID, followeeID _: UUID) async throws {
        followCalls += 1
        try followResult.get()
    }

    func unfollow(followerID _: UUID, followeeID _: UUID) async throws {
        unfollowCalls += 1
        try unfollowResult.get()
    }

    func followers(of _: UUID, limit _: Int) async throws -> [UserProfile] {
        try followersResult.get()
    }

    func following(of _: UUID, limit _: Int) async throws -> [UserProfile] {
        try followingResult.get()
    }
}
