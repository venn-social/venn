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

    @Test
    func refreshFollowCountsPatchesLoadedSnapshotInPlace() async {
        let profile = makeProfile(username: "ada")
        let service = FakeProfileService()
        service.result = .success(profile)
        service.followCountsResult = .success(FollowCounts(followers: 1, following: 0))
        let viewModel = ProfileViewModel(userID: profile.id, service: service)
        await viewModel.load()

        service.followCountsResult = .success(FollowCounts(followers: 2, following: 0))
        await viewModel.refreshFollowCounts()

        #expect(viewModel.state == .loaded(
            .init(
                profile: profile,
                followCounts: FollowCounts(followers: 2, following: 0),
                collection: [],
                watchlist: []
            )
        ))
    }

    @Test
    func refreshFollowCountsKeepsStaleCountsOnFailure() async {
        let profile = makeProfile(username: "ada")
        let counts = FollowCounts(followers: 1, following: 0)
        let service = FakeProfileService()
        service.result = .success(profile)
        service.followCountsResult = .success(counts)
        let viewModel = ProfileViewModel(userID: profile.id, service: service)
        await viewModel.load()

        service.followCountsResult = .failure(AppError.network)
        await viewModel.refreshFollowCounts()

        #expect(viewModel.state == .loaded(
            .init(profile: profile, followCounts: counts, collection: [], watchlist: [])
        ))
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
    var uploadAvatarResult: Result<URL, Error> = .success(URL(filePath: "/dev/null"))
    var followCountsResult: Result<FollowCounts, Error> = .success(.zero)
    var collectionResult: Result<[LibraryItem], Error> = .success([])
    var watchlistResult: Result<[LibraryItem], Error> = .success([])
    private(set) var lastRequestedID: UUID?
    private(set) var lastFollowCountsID: UUID?
    private(set) var updateCalls: [UpdateCall] = []
    private(set) var uploadedAvatarData: [Data] = []

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

    func uploadAvatar(userID _: UUID, jpegData: Data) async throws -> URL {
        uploadedAvatarData.append(jpegData)
        return try uploadAvatarResult.get()
    }

    func followCounts(for userID: UUID) async throws -> FollowCounts {
        lastFollowCountsID = userID
        return try followCountsResult.get()
    }

    func updatePrivacy(userID _: UUID, isPrivate _: Bool) async throws {}

    func watchlist(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        try watchlistResult.get()
    }

    func collection(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        try collectionResult.get()
    }

    func removeFromLibrary(postID _: UUID) async throws {}

    private struct NotConfigured: Error {}
}
