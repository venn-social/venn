import Foundation
import Testing
@testable import Venn

/// Pagination + refresh behavior of `FeedViewModel` against a paging fake.
/// The wire layer has its own tests (`FeedServiceTests`); these cover the
/// state machine: appending, cursor passing, dedup, exhaustion, and the
/// keep-stale-content-on-refresh-failure rule.
@MainActor
struct FeedViewModelTests {
    @Test
    func fullFirstPageLoadsAndExpectsMore() async {
        let service = FakeFeedService(pages: [Self.posts(0..<3)])
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()

        #expect(viewModel.state == .loaded(Self.posts(0..<3)))
        #expect(viewModel.hasMore)
        #expect(service.calls.first?.before == nil)
    }

    @Test
    func shortFirstPageMeansFeedIsExhausted() async {
        let service = FakeFeedService(pages: [Self.posts(0..<2)])
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()

        #expect(!viewModel.hasMore)
    }

    @Test
    func loadMoreAppendsNextPageUsingLastPostAsCursor() async {
        let service = FakeFeedService(pages: [Self.posts(0..<3), Self.posts(3..<6)])
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()
        await viewModel.loadMore()

        #expect(viewModel.state == .loaded(Self.posts(0..<6)))
        #expect(viewModel.hasMore)
        #expect(service.calls.count == 2)
        #expect(service.calls[1].before == Self.posts(0..<3).last?.post.createdAt)
    }

    @Test
    func loadMoreNeverDuplicatesAnOverlappingPost() async {
        // Page 2 re-includes post 2 (same-instant cursor edge case).
        let service = FakeFeedService(pages: [Self.posts(0..<3), Self.posts(2..<5)])
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()
        await viewModel.loadMore()

        #expect(viewModel.state == .loaded(Self.posts(0..<5)))
    }

    @Test
    func shortSecondPageStopsPaging() async {
        let service = FakeFeedService(pages: [Self.posts(0..<3), Self.posts(3..<4)])
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()
        await viewModel.loadMore()
        #expect(!viewModel.hasMore)

        await viewModel.loadMore()
        #expect(service.calls.count == 2, "exhausted feed must not refetch")
    }

    @Test
    func loadMoreFailureStopsPagingButKeepsContent() async {
        let service = FakeFeedService(pages: [Self.posts(0..<3)])
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()
        service.error = AppError.network
        await viewModel.loadMore()

        #expect(viewModel.state == .loaded(Self.posts(0..<3)))
        #expect(!viewModel.hasMore)
    }

    @Test
    func refreshFailureKeepsStaleContentOnScreen() async {
        let service = FakeFeedService(pages: [Self.posts(0..<3)])
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()
        service.error = AppError.network
        await viewModel.refresh()

        #expect(viewModel.state == .loaded(Self.posts(0..<3)))
    }

    @Test
    func refreshRestartsPaginationFromTheTop() async {
        let service = FakeFeedService(pages: [Self.posts(0..<3), Self.posts(0..<3)])
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()
        await viewModel.loadMore() // fake is now out of pages → error → hasMore = false

        service.pages = [Self.posts(0..<3)]
        service.error = nil
        await viewModel.refresh()

        #expect(viewModel.hasMore)
    }

    @Test
    func initialLoadFailureMapsToErrorReason() async {
        let service = FakeFeedService(pages: [])
        service.error = AppError.network
        let viewModel = FeedViewModel(service: service, pageSize: 3)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    // MARK: - Likes and comment counts

    @Test
    func loadsLikesAndCommentCountsForThePageInOneCallEach() async {
        // Two calls per page, not two per row: 20 posts would otherwise be
        // 40 extra round trips.
        let social = FakeFeedSocialService()
        let posts = Self.posts(0..<3)
        social.likes = [posts[0].id: LikeInfo(likeCount: 2, likedByMe: true)]
        social.counts = [posts[0].id: 5]
        let viewModel = FeedViewModel(
            service: FakeFeedService(pages: [posts]),
            socialService: social,
            pageSize: 3
        )

        await viewModel.load()

        #expect(viewModel.social(for: posts[0].id).likes.likeCount == 2)
        #expect(viewModel.social(for: posts[0].id).commentCount == 5)
        #expect(social.likeCalls.count == 1)
        #expect(social.countCalls.count == 1)
        #expect(social.likeCalls.first?.count == 3)
    }

    @Test
    func aPostWithNoLikesOrCommentsReadsAsZero() async {
        let posts = Self.posts(0..<2)
        let viewModel = FeedViewModel(
            service: FakeFeedService(pages: [posts]),
            socialService: FakeFeedSocialService(),
            pageSize: 2
        )

        await viewModel.load()

        #expect(viewModel.social(for: posts[1].id) == .none)
    }

    @Test
    func socialFailureLeavesTheFeedOnScreen() async {
        // These counts are decoration; the feed is the content. A row with
        // no heart beside it beats an error screen where the feed was.
        let social = FakeFeedSocialService()
        social.error = AppError.network
        let viewModel = FeedViewModel(
            service: FakeFeedService(pages: [Self.posts(0..<3)]),
            socialService: social,
            pageSize: 3
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded(Self.posts(0..<3)))
        #expect(viewModel.social(for: Self.posts(0..<1)[0].id) == .none)
    }

    @Test
    func loadMoreFetchesCountsForTheNewPageOnly() async {
        let social = FakeFeedSocialService()
        let viewModel = FeedViewModel(
            service: FakeFeedService(pages: [Self.posts(0..<3), Self.posts(3..<6)]),
            socialService: social,
            pageSize: 3
        )

        await viewModel.load()
        await viewModel.loadMore()

        #expect(social.likeCalls.count == 2)
        #expect(social.likeCalls[1] == Self.posts(3..<6).map(\.id))
    }

    @Test
    func worksWithoutASocialServiceAtAll() async {
        // The DEBUG design-preview boot has no signed-in viewer.
        let viewModel = FeedViewModel(service: FakeFeedService(pages: [Self.posts(0..<2)]))

        await viewModel.load()

        #expect(viewModel.state == .loaded(Self.posts(0..<2)))
        #expect(viewModel.social(for: Self.posts(0..<1)[0].id) == .none)
    }

    // MARK: - Fixtures

    /// Deterministic posts: post `i` is `i` minutes older than the base
    /// date, so "newest first" ordering and cursor math are stable.
    private static func posts(_ range: Range<Int>) -> [FeedPost] {
        range.map { index in
            let id = UUID(uuidString: String(
                format: "00000000-0000-0000-0000-%012d", index
            )) ?? UUID()
            let created = Date(timeIntervalSince1970: 1_700_000_000 - Double(index) * 60)
            return FeedPost(
                post: Post(
                    id: id,
                    authorID: Self.authorID,
                    mediaID: Self.mediaID,
                    action: .logged,
                    rating: nil,
                    caption: nil,
                    createdAt: created
                ),
                media: Media(
                    id: Self.mediaID,
                    kind: .movie,
                    title: "Past Lives",
                    year: 2023,
                    primaryCreator: nil,
                    coverURL: nil,
                    externalID: nil,
                    externalSource: nil,
                    createdAt: created
                ),
                author: UserProfile(
                    id: Self.authorID,
                    username: "maya",
                    displayName: nil,
                    avatarURL: nil,
                    bio: nil,
                    createdAt: created
                )
            )
        }
    }

    private static let authorID = UUID(
        uuidString: "11111111-1111-1111-1111-111111111111"
    ) ?? UUID()
    private static let mediaID = UUID(
        uuidString: "22222222-2222-2222-2222-222222222222"
    ) ?? UUID()
}

// MARK: - Fake

/// Paging fake: each call pops the next page; records (limit, before) so
/// tests can assert the cursor. Set `error` to fail the next call.
final class FakeFeedService: FeedServicing, @unchecked Sendable {
    var pages: [[FeedPost]]
    var error: AppError?
    private(set) var calls: [(limit: Int, before: Date?)] = []

    init(pages: [[FeedPost]]) {
        self.pages = pages
    }

    func recentPosts(limit: Int, before: Date?) async throws -> [FeedPost] {
        calls.append((limit, before))
        if let error {
            throw error
        }
        guard !pages.isEmpty else { throw AppError.network }
        return pages.removeFirst()
    }

    var quickActionError: AppError?
    private(set) var logged: [(authorID: UUID, mediaID: UUID)] = []
    private(set) var saved: [(authorID: UUID, mediaID: UUID)] = []

    func logFromFeed(authorID: UUID, mediaID: UUID) async throws {
        if let quickActionError {
            throw quickActionError
        }
        logged.append((authorID, mediaID))
    }

    func saveToWatchlist(authorID: UUID, mediaID: UUID) async throws {
        if let quickActionError {
            throw quickActionError
        }
        saved.append((authorID, mediaID))
    }
}

/// Records which post ids each batch call asked for, so tests can assert
/// the feed batches per page rather than per row.
final class FakeFeedSocialService: SocialServicing, @unchecked Sendable {
    var likes: [UUID: LikeInfo] = [:]
    var counts: [UUID: Int] = [:]
    var error: AppError?
    private(set) var likeCalls: [[UUID]] = []
    private(set) var countCalls: [[UUID]] = []

    func likeInfo(postIDs: [UUID]) async throws -> [UUID: LikeInfo] {
        likeCalls.append(postIDs)
        if let error {
            throw error
        }
        return likes
    }

    func commentCounts(postIDs: [UUID]) async throws -> [UUID: Int] {
        countCalls.append(postIDs)
        if let error {
            throw error
        }
        return counts
    }

    func like(postID _: UUID, userID _: UUID) async throws {}
    func unlike(postID _: UUID, userID _: UUID) async throws {}
    func comments(postID _: UUID, limit _: Int) async throws -> [PostComment] {
        []
    }

    func addComment(postID _: UUID, authorID _: UUID, body _: String) async throws {}
    func editComment(commentID _: UUID, body _: String) async throws {}

    func deleteComment(commentID _: UUID) async throws {}
}

/// Logging or saving something spotted on someone else's feed.
@MainActor
struct FeedQuickActionTests {
    private func makeViewModel(_ service: FakeFeedService) -> FeedViewModel {
        FeedViewModel(service: service, socialService: FakeFeedSocialService())
    }

    @Test
    func loggingWritesForTheViewerNotThePostsAuthor() async {
        // The whole point is adding someone else's find to *your* library.
        let service = FakeFeedService(pages: [[]])
        let viewModel = makeViewModel(service)
        let viewer = UUID()
        let media = UUID()

        await viewModel.performQuickAction(.log, mediaID: media, viewerID: viewer)

        #expect(service.logged.count == 1)
        #expect(service.logged[0].authorID == viewer)
        #expect(service.logged[0].mediaID == media)
        #expect(service.saved.isEmpty)
    }

    @Test
    func addingToWatchlistTakesTheSaveePathNotTheLogPath() async {
        // These are different writes: one promotes, the other must not
        // clobber an entry that already exists.
        let service = FakeFeedService(pages: [[]])
        let viewModel = makeViewModel(service)

        await viewModel.performQuickAction(.watchlist, mediaID: UUID(), viewerID: UUID())

        #expect(service.saved.count == 1)
        #expect(service.logged.isEmpty)
    }

    @Test
    func aSuccessfulActionReportsWhereTheItemWent() async {
        let service = FakeFeedService(pages: [[]])
        let viewModel = makeViewModel(service)

        await viewModel.performQuickAction(.log, mediaID: UUID(), viewerID: UUID())
        #expect(viewModel.lastQuickActionMessage == "Added to your collection")

        await viewModel.performQuickAction(.watchlist, mediaID: UUID(), viewerID: UUID())
        #expect(viewModel.lastQuickActionMessage == "Added to your watchlist")
    }

    @Test
    func aFailedActionSaysSoRatherThanClaimingSuccess() async {
        // Nothing else on this screen changes, so a silent failure would
        // read as success and the item would simply never be there.
        let service = FakeFeedService(pages: [[]])
        service.quickActionError = .network
        let viewModel = makeViewModel(service)

        await viewModel.performQuickAction(.log, mediaID: UUID(), viewerID: UUID())

        #expect(viewModel.lastQuickActionMessage == "Couldn't do that. Please try again.")
        #expect(service.logged.isEmpty)
    }
}

/// The labels the menu shows, which have to match web's FeedItemMenu.
struct LibraryQuickActionTests {
    @Test
    func offersLogThenWatchlistWithWebsLabels() {
        #expect(LibraryQuickAction.allCases.map(\.title) == ["Log", "Add to Watchlist"])
    }

    @Test
    func everyActionHasAnIconAndAConfirmation() {
        for action in LibraryQuickAction.allCases {
            #expect(!action.systemImage.isEmpty)
            #expect(!action.confirmation.isEmpty)
        }
    }
}
