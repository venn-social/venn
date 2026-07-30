import Foundation
import Testing
@testable import Venn

@MainActor
struct FollowViewModelTests {
    // MARK: - load()

    @Test
    func loadMapsAcceptedEdgeToFollowingState() async {
        let service = FakeFollowService()
        service.followStatusResult = .success(.accepted)
        let viewModel = makeViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .following)
    }

    @Test
    func loadMapsPendingEdgeToRequestedState() async {
        let service = FakeFollowService()
        service.followStatusResult = .success(.pending)
        let viewModel = makeViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .requested)
    }

    @Test
    func loadMapsMissingEdgeToNotFollowing() async {
        let service = FakeFollowService()
        service.followStatusResult = .success(nil)
        let viewModel = makeViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .notFollowing)
    }

    @Test
    func loadFailureFallsBackToNotFollowing() async {
        // Deliberate: requestFollow is safe to retry, so showing "Follow"
        // when the check failed self-heals on tap instead of hiding the
        // button entirely.
        let service = FakeFollowService()
        service.followStatusResult = .failure(AppError.network)
        let viewModel = makeViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .notFollowing)
    }

    // MARK: - toggle() from .notFollowing

    @Test
    func toggleFromNotFollowingOnPublicTargetLandsOnFollowing() async {
        let service = FakeFollowService()
        service.requestFollowResult = .success(.accepted)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .following)
        #expect(service.requestFollowCalls == 1)
    }

    @Test
    func toggleFromNotFollowingOnPrivateTargetLandsOnRequested() async {
        let service = FakeFollowService()
        service.requestFollowResult = .success(.pending)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .requested)
    }

    @Test
    func failedRequestFollowLeavesStateAtNotFollowing() async {
        // Not optimistic (the outcome depends on the server), so a failure
        // just leaves the button at its starting point rather than reverting
        // a flip that never happened.
        let service = FakeFollowService()
        service.requestFollowResult = .failure(AppError.network)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .notFollowing)
    }

    // MARK: - toggle() from .following / .requested (both a delete)

    @Test
    func toggleFromFollowingCallsUnfollowAndLandsOnNotFollowing() async {
        let service = FakeFollowService()
        service.followStatusResult = .success(.accepted)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .notFollowing)
        #expect(service.unfollowCalls == 1)
    }

    @Test
    func toggleFromRequestedCancelsAndLandsOnNotFollowing() async {
        let service = FakeFollowService()
        service.followStatusResult = .success(.pending)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .notFollowing)
        #expect(service.unfollowCalls == 1)
    }

    @Test
    func failedUnfollowRevertsTheOptimisticFlip() async {
        let service = FakeFollowService()
        service.followStatusResult = .success(.accepted)
        service.unfollowResult = .failure(AppError.server)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .following)
    }

    @Test
    func failedCancelRevertsToRequested() async {
        let service = FakeFollowService()
        service.followStatusResult = .success(.pending)
        service.unfollowResult = .failure(AppError.server)
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        await viewModel.toggle()

        #expect(viewModel.state == .requested)
    }

    // MARK: - Re-entrancy

    @Test
    func reentrantToggleWhileWorkingIsIgnored() async {
        let service = FakeFollowService()
        let viewModel = makeViewModel(service: service)
        await viewModel.load()

        async let first: Void = viewModel.toggle()
        async let second: Void = viewModel.toggle()
        _ = await (first, second)

        // Only one request should have gone out; the second tap landed
        // while isWorking was already true and was dropped.
        #expect(service.requestFollowCalls == 1)
    }

    // MARK: - Helpers

    private func makeViewModel(service: FakeFollowService) -> FollowViewModel {
        FollowViewModel(followerID: UUID(), followeeID: UUID(), service: service)
    }
}

// MARK: - Fake

final class FakeFollowService: FollowServicing, @unchecked Sendable {
    var followStatusResult: Result<FollowStatus?, Error> = .success(nil)
    var requestFollowResult: Result<FollowStatus, Error> = .success(.accepted)
    var unfollowResult: Result<Void, Error> = .success(())
    var respondResult: Result<Void, Error> = .success(())
    var followersResult: Result<[UserProfile], Error> = .success([])
    var followingResult: Result<[UserProfile], Error> = .success([])
    var pendingRequestsResult: Result<[UserProfile], Error> = .success([])
    private(set) var requestFollowCalls = 0
    private(set) var unfollowCalls = 0
    private(set) var respondCalls = 0

    func followStatus(followerID _: UUID, followeeID _: UUID) async throws -> FollowStatus? {
        try followStatusResult.get()
    }

    func requestFollow(followerID _: UUID, followeeID _: UUID) async throws -> FollowStatus {
        requestFollowCalls += 1
        return try requestFollowResult.get()
    }

    func unfollow(followerID _: UUID, followeeID _: UUID) async throws {
        unfollowCalls += 1
        try unfollowResult.get()
    }

    func respondToRequest(followerID _: UUID, followeeID _: UUID, accept _: Bool) async throws {
        respondCalls += 1
        try respondResult.get()
    }

    func followers(of _: UUID, limit _: Int) async throws -> [UserProfile] {
        try followersResult.get()
    }

    func following(of _: UUID, limit _: Int) async throws -> [UserProfile] {
        try followingResult.get()
    }

    func pendingRequests(for _: UUID, limit _: Int) async throws -> [UserProfile] {
        try pendingRequestsResult.get()
    }
}
