import Foundation
import Testing
@testable import Venn

#if DEBUG
    struct StubFeedServiceTests {
        private let service = StubFeedService()

        @Test
        func firstPageIsNewestFirst() async throws {
            let posts = try await service.recentPosts(limit: 20, before: nil)

            #expect(posts == StubFeedService.posts)
            #expect(posts.map(\.post.createdAt) == posts.map(\.post.createdAt).sorted(by: >))
        }

        @Test
        func limitCapsThePage() async throws {
            let posts = try await service.recentPosts(limit: 2, before: nil)

            #expect(posts == Array(StubFeedService.posts.prefix(2)))
        }

        @Test
        func cursorReturnsOnlyStrictlyOlderPosts() async throws {
            let first = try await service.recentPosts(limit: 2, before: nil)
            let cursor = try #require(first.last?.post.createdAt)

            let next = try await service.recentPosts(limit: 2, before: cursor)

            #expect(next == Array(StubFeedService.posts.dropFirst(2)))
        }

        @Test
        func everyLaunchRendersTheSameFeed() async throws {
            let once = try await service.recentPosts(limit: 20, before: nil)
            let again = try await StubFeedService().recentPosts(limit: 20, before: nil)

            #expect(once.map(\.id) == again.map(\.id))
        }
    }
#endif
