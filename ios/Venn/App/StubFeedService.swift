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
        static let posts: [FeedPost] = [
            post(
                index: 0,
                title: "Past Lives",
                kind: .movie,
                creator: "Celine Song",
                year: 2023,
                caption: "Quietly devastating. Stayed with me for days."
            ),
            post(
                index: 1,
                title: "Tomorrow, and Tomorrow, and Tomorrow",
                kind: .book,
                creator: "Gabrielle Zevin",
                year: 2022,
                caption: nil
            ),
            post(
                index: 2,
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
            title: String,
            kind: MediaKind,
            creator: String,
            year: Int,
            caption: String?
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
                    caption: caption,
                    createdAt: createdAt
                ),
                media: Media(
                    id: mediaID,
                    kind: kind,
                    title: title,
                    year: year,
                    primaryCreator: creator,
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
