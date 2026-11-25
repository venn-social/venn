import Foundation

#if DEBUG
    /// Opt-in switch for in-memory services, read from the launch arguments.
    /// UI tests set it so service-backed screens render fixed content instead
    /// of whatever real users happen to have posted to the shared remote DB.
    enum StubServices {
        static let launchArgument = "-useStubServices"

        static var isEnabled: Bool {
            ProcessInfo.processInfo.arguments.contains(launchArgument)
        }
    }

    /// Deterministic `FeedServicing` for UI tests. Pages through a fixed list
    /// with the same keyset contract as `FeedService`; the quick actions
    /// succeed without writing anything.
    struct StubFeedService: FeedServicing {
        static let posts: [FeedPost] = fixtures.enumerated().map { index, fixture in
            post(index: index, fixture: fixture)
        }

        private struct Fixture {
            let title: String
            let kind: MediaKind
            let creator: String
            let year: Int
            let caption: String?
        }

        private static let fixtures: [Fixture] = [
            Fixture(
                title: "Past Lives",
                kind: .movie,
                creator: "Celine Song",
                year: 2023,
                caption: "Quietly devastating. Stayed with me for days."
            ),
            Fixture(
                title: "Tomorrow, and Tomorrow, and Tomorrow",
                kind: .book,
                creator: "Gabrielle Zevin",
                year: 2022,
                caption: nil
            ),
            Fixture(
                title: "Blonde",
                kind: .album,
                creator: "Frank Ocean",
                year: 2016,
                caption: "Still the one I come back to."
            ),
        ]

        func recentPosts(limit: Int, before: Date?) async throws -> [FeedPost] {
            let older = Self.posts.filter { feedPost in
                before.map { feedPost.post.createdAt < $0 } ?? true
            }
            return Array(older.prefix(limit))
        }

        func logFromFeed(authorID _: UUID, mediaID _: UUID) async throws {}

        func saveToWatchlist(authorID _: UUID, mediaID _: UUID) async throws {}

        /// Fixed ids and timestamps so every launch renders the same feed;
        /// post `index` is `index` hours older than the newest.
        private static func post(
            index: Int,
            fixture: Fixture
        ) -> FeedPost {
            let postID = fixedID(prefix: "a", index: index)
            let mediaID = fixedID(prefix: "b", index: index)
            let createdAt = Date(timeIntervalSince1970: newestPostTime - Double(index) * secondsPerHour)
            return FeedPost(
                post: Post(
                    id: postID,
                    authorID: author.id,
                    mediaID: mediaID,
                    action: .logged,
                    rating: nil,
                    caption: fixture.caption,
                    createdAt: createdAt
                ),
                media: Media(
                    id: mediaID,
                    kind: fixture.kind,
                    title: fixture.title,
                    year: fixture.year,
                    primaryCreator: fixture.creator,
                    coverURL: nil,
                    externalID: nil,
                    externalSource: nil,
                    createdAt: createdAt
                ),
                author: author
            )
        }

        private static func fixedID(prefix: String, index: Int) -> UUID {
            UUID(uuidString: String(format: "\(prefix)0000000-0000-4000-8000-%012d", index)) ?? UUID()
        }

        private static let newestPostTime: TimeInterval = 1_764_000_000
        private static let secondsPerHour: TimeInterval = 3600

        private static let author = UserProfile(
            id: UUID(uuidString: "c0000000-0000-4000-8000-000000000001") ?? UUID(),
            username: "stub_reader",
            displayName: nil,
            avatarURL: nil,
            bio: nil,
            createdAt: Date(timeIntervalSince1970: newestPostTime)
        )
    }
#endif
