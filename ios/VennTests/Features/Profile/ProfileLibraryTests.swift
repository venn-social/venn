import Foundation
import Testing
@testable import Venn

/// Tests for `LibraryViewModel` state machine. All network calls go through
/// `FakeLibraryService` — no real HTTP or Supabase in these tests.
@MainActor
struct ProfileLibraryTests {
    // MARK: - Load watchlist

    @Test
    func loadWatchlistSetsLoadedState() async {
        let service = FakeLibraryService()
        service.watchlistResult = .success([makeItem(action: .saved)])
        let viewModel = LibraryViewModel(
            userID: UUID(),
            kind: .movie,
            shelf: .watchlist,
            service: service
        )

        await viewModel.load()

        guard case let .loaded(items) = viewModel.state else {
            Issue.record("Expected .loaded, got \(viewModel.state)")
            return
        }
        #expect(items.count == 1)
        #expect(items[0].post.action == .saved)
    }

    @Test
    func loadCollectionSetsLoadedState() async {
        let service = FakeLibraryService()
        service.collectionResult = .success([makeItem(action: .rated), makeItem(action: .logged)])
        let viewModel = LibraryViewModel(
            userID: UUID(),
            kind: nil,
            shelf: .collection,
            service: service
        )

        await viewModel.load()

        guard case let .loaded(items) = viewModel.state else {
            Issue.record("Expected .loaded, got \(viewModel.state)")
            return
        }
        #expect(items.count == 2)
    }

    @Test
    func loadEmptyResultsShowsLoadedWithEmptyArray() async {
        let service = FakeLibraryService()
        service.watchlistResult = .success([])
        let viewModel = LibraryViewModel(userID: UUID(), kind: nil, shelf: .watchlist, service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded([]))
    }

    // MARK: - Load errors

    @Test
    func loadNetworkErrorFlipsToOffline() async {
        let service = FakeLibraryService()
        service.watchlistResult = .failure(AppError.network)
        let viewModel = LibraryViewModel(userID: UUID(), kind: nil, shelf: .watchlist, service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func loadUnknownErrorFlipsToUnknown() async {
        struct Boom: Error {}
        let service = FakeLibraryService()
        service.watchlistResult = .failure(Boom())
        let viewModel = LibraryViewModel(userID: UUID(), kind: nil, shelf: .watchlist, service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.unknown))
    }

    // MARK: - Remove

    @Test
    func removeOptimisticallyDeletesItemFromList() async {
        let item = makeItem(action: .saved)
        let service = FakeLibraryService()
        service.watchlistResult = .success([item])
        service.removeResult = .success(())
        let viewModel = LibraryViewModel(userID: UUID(), kind: nil, shelf: .watchlist, service: service)
        await viewModel.load()

        await viewModel.remove(item: item)

        #expect(viewModel.state == .loaded([]))
        #expect(service.removedPostIDs == [item.post.id])
    }

    @Test
    func removeRevertsOnFailure() async {
        let item = makeItem(action: .saved)
        let service = FakeLibraryService()
        service.watchlistResult = .success([item])
        service.removeResult = .failure(AppError.network)
        let viewModel = LibraryViewModel(userID: UUID(), kind: nil, shelf: .watchlist, service: service)
        await viewModel.load()

        await viewModel.remove(item: item)

        // After failure the view model reloads — service returns [item] again
        guard case let .loaded(items) = viewModel.state else {
            Issue.record("Expected .loaded after revert, got \(viewModel.state)")
            return
        }
        #expect(items.count == 1)
    }

    @Test
    func removeDoesNothingWhenNotInLoadedState() async {
        let service = FakeLibraryService()
        let viewModel = LibraryViewModel(userID: UUID(), kind: nil, shelf: .watchlist, service: service)
        // State is .loading — remove should be a no-op

        await viewModel.remove(item: makeItem(action: .saved))

        #expect(service.removedPostIDs.isEmpty)
    }

    // MARK: - Helpers

    private func makeItem(action: PostAction) -> LibraryItem {
        let post = Post(
            id: UUID(),
            authorID: UUID(),
            mediaID: UUID(),
            action: action,
            rating: action == .rated ? 5.0 : nil,
            caption: nil,
            createdAt: Date()
        )
        let media = Media(
            id: UUID(),
            kind: .movie,
            title: "Past Lives",
            year: 2023,
            primaryCreator: "Celine Song",
            coverURL: nil,
            externalID: "976573",
            externalSource: .tmdb,
            createdAt: Date()
        )
        return LibraryItem(post: post, media: media)
    }
}

// MARK: - Fake

final class FakeLibraryService: ProfileServicing, @unchecked Sendable {
    var result: Result<UserProfile, Error> = .failure(NotConfigured())
    var updateResult: Result<Void, Error> = .success(())
    var followCountsResult: Result<FollowCounts, Error> = .success(.zero)
    var watchlistResult: Result<[LibraryItem], Error> = .success([])
    var collectionResult: Result<[LibraryItem], Error> = .success([])
    var removeResult: Result<Void, Error> = .success(())

    private(set) var removedPostIDs: [UUID] = []
    private(set) var reordered: [[UUID]] = []

    func profile(for _: UUID) async throws -> UserProfile {
        try result.get()
    }

    func updateProfile(userID _: UUID, displayName _: String?, bio _: String?) async throws {
        try updateResult.get()
    }

    func followCounts(for _: UUID) async throws -> FollowCounts {
        try followCountsResult.get()
    }

    func updatePrivacy(userID _: UUID, isPrivate _: Bool) async throws {}

    func watchlist(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        try watchlistResult.get()
    }

    func collection(for _: UUID, kind _: MediaKind?) async throws -> [LibraryItem] {
        try collectionResult.get()
    }

    func updateRating(postID _: UUID, action _: PostAction, rating _: Double?) async throws {}

    func reorderLibrary(postIDs: [UUID]) async throws {
        reordered.append(postIDs)
    }

    func removeFromLibrary(postID: UUID) async throws {
        removedPostIDs.append(postID)
        try removeResult.get()
    }

    func uploadAvatar(userID _: UUID, jpegData _: Data) async throws -> URL {
        URL(filePath: "/dev/null")
    }

    private struct NotConfigured: Error {}
}
