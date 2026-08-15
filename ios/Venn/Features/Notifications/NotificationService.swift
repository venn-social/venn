import Foundation
import Supabase

/// What happened. Mirrors the `notifications_kind_valid` CHECK and web's
/// `NotificationKind`.
enum NotificationKind: String, Codable, Hashable, Sendable {
    case like
    case comment
    case follow
    case followRequest = "follow_request"

    /// SF Symbol for the row's leading glyph.
    var systemImage: String {
        switch self {
        case .like: "heart.fill"
        case .comment: "bubble.right.fill"
        case .follow: "person.fill.badge.plus"
        case .followRequest: "person.crop.circle.badge.questionmark"
        }
    }
}

/// One thing that happened to you.
struct AppNotification: Identifiable, Equatable, Hashable, Sendable {
    let id: UUID
    let kind: NotificationKind
    /// Who caused it.
    let actor: UserProfile
    let createdAt: Date
    /// Nil until seen.
    let readAt: Date?
    /// Set for like and comment; nil for the follow kinds.
    let postID: UUID?
    /// The title the post was about, for "liked your post about Past Lives".
    let postTitle: String?
    /// The comment's text, so the row can quote it rather than announce it.
    let commentBody: String?

    var isUnread: Bool {
        readAt == nil
    }

    /// The sentence the row shows. Copy matches web's
    /// `notificationSummary` exactly (CLAUDE.md rule 17).
    ///
    /// The title rides along when we have it: "liked your post" is
    /// forgettable, "liked your post about Past Lives" is worth opening.
    var summary: String {
        let about = postTitle.map { " about \($0)" } ?? ""
        return switch kind {
        case .like: "liked your post\(about)"
        case .comment: "commented on your post\(about)"
        case .follow: "started following you"
        case .followRequest: "asked to follow you"
        }
    }
}

/// Behind a protocol so the view-model unit-tests with a fake (ADR 0005).
protocol NotificationServicing: Sendable {
    func notifications(limit: Int) async throws -> [AppNotification]
    func unreadCount() async throws -> Int
    /// Returns how many were cleared, so the caller can skip a refetch when
    /// it's zero.
    @discardableResult
    func markAllRead() async throws -> Int

    /// Changes to the signed-in user's notifications, as they happen.
    ///
    /// Yields on any insert, update or delete rather than carrying a
    /// payload: callers re-read the count, which handles something marked
    /// read on another device as well as something arriving, where adding
    /// and subtracting locally would not.
    ///
    /// RLS applies to Realtime, so the stream can only ever deliver the
    /// reader's own rows — the same guarantee a SELECT gets.
    func changes() -> AsyncStream<Void>
}

/// Production implementation backed by Supabase Postgrest. Funnels
/// third-party errors through `AppError.from(_:)` so callers see one
/// semantic error type (ADR 0006).
struct NotificationService: NotificationServicing {
    let client: SupabaseClient

    /// The actor foreign key is named explicitly, and must stay that way:
    /// `notifications` references `profiles` twice (recipient and actor), so
    /// a bare `profiles(*)` embed is ambiguous and fails with PGRST201.
    /// That exact mistake took the feed down on both platforms once.
    private static let selection = """
    id, kind, created_at, read_at, post_id, \
    actor:profiles!notifications_actor_id_fkey(*), \
    post:posts(media(title)), \
    comment:post_comments(body)
    """

    func notifications(limit: Int = 50) async throws -> [AppNotification] {
        do {
            let rows: [NotificationRowDTO] = try await client
                .from("notifications")
                .select(Self.selection)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.compactMap(AppNotification.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }

    func unreadCount() async throws -> Int {
        do {
            // Through the RPC rather than a client-side count: the badge
            // wants one round trip with no rows on the wire.
            return try await client
                .rpc("unread_notification_count")
                .execute()
                .value
        } catch {
            throw AppError.from(error)
        }
    }

    @discardableResult
    func markAllRead() async throws -> Int {
        do {
            return try await client
                .rpc("mark_notifications_read")
                .execute()
                .value
        } catch {
            throw AppError.from(error)
        }
    }
}

// MARK: - Wire format

struct NotificationRowDTO: Decodable, Equatable {
    let id: UUID
    let kind: String
    let createdAt: Date
    let readAt: Date?
    let postId: UUID?
    let actor: UserProfile?
    let post: NotificationPostDTO?
    let comment: NotificationCommentDTO?

    enum CodingKeys: String, CodingKey {
        case id, kind, actor, post, comment
        case createdAt = "created_at"
        case readAt = "read_at"
        case postId = "post_id"
    }
}

struct NotificationPostDTO: Decodable, Equatable {
    let media: NotificationMediaDTO?
}

struct NotificationMediaDTO: Decodable, Equatable {
    let title: String?
}

struct NotificationCommentDTO: Decodable, Equatable {
    let body: String?
}

extension AppNotification {
    /// Lift a wire row into the domain type. Nil when the row can't be
    /// rendered honestly — an unknown kind, or an actor that vanished
    /// mid-flight. "Someone liked your post" is worse than nothing.
    init?(row: NotificationRowDTO) {
        guard let kind = NotificationKind(rawValue: row.kind), let actor = row.actor else {
            return nil
        }
        self.init(
            id: row.id,
            kind: kind,
            actor: actor,
            createdAt: row.createdAt,
            readAt: row.readAt,
            postID: row.postId,
            postTitle: row.post?.media?.title,
            commentBody: row.comment?.body
        )
    }
}

extension NotificationService {
    func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let channel = client.realtimeV2.channel("notifications-badge")

            let task = Task {
                let inserts = channel.postgresChange(InsertAction.self, table: "notifications")
                let updates = channel.postgresChange(UpdateAction.self, table: "notifications")
                let deletes = channel.postgresChange(DeleteAction.self, table: "notifications")

                await channel.subscribe()

                // Merged rather than watched separately: every caller wants
                // the same thing from all three, which is "look again".
                await withTaskGroup(of: Void.self) { group in
                    group.addTask { await Self.forward(inserts, to: continuation) }
                    group.addTask { await Self.forward(updates, to: continuation) }
                    group.addTask { await Self.forward(deletes, to: continuation) }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                Task { await channel.unsubscribe() }
            }
        }
    }

    /// Collapses a typed change stream into a bare "something happened".
    /// The payload is deliberately dropped — callers re-read the count.
    private static func forward<Change: Sendable>(
        _ stream: AsyncStream<Change>,
        to continuation: AsyncStream<Void>.Continuation
    ) async {
        for await _ in stream {
            continuation.yield()
        }
    }
}
