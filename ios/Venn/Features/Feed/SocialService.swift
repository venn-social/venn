import Foundation
import Supabase

/// Like count for one post, plus whether the signed-in viewer liked it.
struct LikeInfo: Equatable, Hashable, Sendable {
    let likeCount: Int
    let likedByMe: Bool

    static let none = LikeInfo(likeCount: 0, likedByMe: false)
}

/// A comment on a post. Flat — replies-to-replies would need a parent id, a
/// depth cap, and a recursive read, none of which is worth building before
/// anyone has commented once.
struct PostComment: Identifiable, Equatable, Sendable {
    let id: UUID
    let body: String
    let createdAt: Date
    let author: UserProfile
}

/// Likes and comments on posts — the social layer over `FeedService`'s
/// read-only stream. Behind a protocol so view-models unit-test with a fake
/// (ADR 0005).
protocol SocialServicing: Sendable {
    /// Like info for many posts in one call. A feed page would otherwise be
    /// two round trips per row.
    func likeInfo(postIDs: [UUID]) async throws -> [UUID: LikeInfo]

    /// Idempotent — `(post_id, user_id)` is the primary key, so liking twice
    /// is one row.
    func like(postID: UUID, userID: UUID) async throws

    func unlike(postID: UUID, userID: UUID) async throws

    /// A post's comments, oldest first — a conversation reads top to bottom.
    func comments(postID: UUID, limit: Int) async throws -> [PostComment]

    func addComment(postID: UUID, authorID: UUID, body: String) async throws

    /// Deletable by the comment's author or the post's author; the RLS
    /// policy decides, so this just issues the delete.
    func deleteComment(commentID: UUID) async throws

    /// Comment counts for many posts at once, batched for the same reason
    /// as `likeInfo`.
    func commentCounts(postIDs: [UUID]) async throws -> [UUID: Int]
}

/// Production implementation backed by Supabase Postgrest. Funnels
/// third-party errors through `AppError.from(_:)` so callers see one
/// semantic error type — same pattern as `FeedService` (ADR 0006).
struct SocialService: SocialServicing {
    let client: SupabaseClient

    func likeInfo(postIDs: [UUID]) async throws -> [UUID: LikeInfo] {
        guard !postIDs.isEmpty else { return [:] }
        do {
            let rows: [LikeInfoRow] = try await client
                .rpc("post_like_info", params: ["post_ids": postIDs.map(\.uuidString)])
                .execute()
                .value
            return Dictionary(
                uniqueKeysWithValues: rows.map {
                    ($0.postId, LikeInfo(likeCount: $0.likeCount, likedByMe: $0.likedByMe))
                }
            )
        } catch {
            throw AppError.from(error)
        }
    }

    func like(postID: UUID, userID: UUID) async throws {
        do {
            try await client
                .from("post_likes")
                .upsert(LikeRow(postId: postID, userId: userID), ignoreDuplicates: true)
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func unlike(postID: UUID, userID: UUID) async throws {
        do {
            try await client
                .from("post_likes")
                .delete()
                .eq("post_id", value: postID)
                .eq("user_id", value: userID)
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func comments(postID: UUID, limit: Int = 100) async throws -> [PostComment] {
        do {
            let rows: [CommentRow] = try await client
                .from("post_comments")
                .select("id, body, created_at, author:profiles(*)")
                .eq("post_id", value: postID)
                .order("created_at", ascending: true)
                .limit(limit)
                .execute()
                .value
            return rows.map(PostComment.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }

    func addComment(postID: UUID, authorID: UUID, body: String) async throws {
        do {
            try await client
                .from("post_comments")
                .insert(CommentInsert(postId: postID, authorId: authorID, body: body))
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func deleteComment(commentID: UUID) async throws {
        do {
            try await client
                .from("post_comments")
                .delete()
                .eq("id", value: commentID)
                .execute()
        } catch {
            throw AppError.from(error)
        }
    }

    func commentCounts(postIDs: [UUID]) async throws -> [UUID: Int] {
        guard !postIDs.isEmpty else { return [:] }
        do {
            let rows: [CommentCountRow] = try await client
                .rpc("post_comment_counts", params: ["post_ids": postIDs.map(\.uuidString)])
                .execute()
                .value
            return Dictionary(uniqueKeysWithValues: rows.map { ($0.postId, $0.commentCount) })
        } catch {
            throw AppError.from(error)
        }
    }
}

// MARK: - Wire formats

/// Wire row for `post_like_info`. Internal so tests can decode it directly.
struct LikeInfoRow: Decodable, Equatable {
    let postId: UUID
    let likeCount: Int
    let likedByMe: Bool

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case likeCount = "like_count"
        case likedByMe = "liked_by_me"
    }
}

struct CommentCountRow: Decodable, Equatable {
    let postId: UUID
    let commentCount: Int

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case commentCount = "comment_count"
    }
}

struct CommentRow: Decodable, Equatable {
    let id: UUID
    let body: String
    let createdAt: Date
    let author: UserProfile

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case createdAt = "created_at"
    }
}

private struct LikeRow: Encodable {
    let postId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case userId = "user_id"
    }
}

private struct CommentInsert: Encodable {
    let postId: UUID
    let authorId: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case authorId = "author_id"
        case body
    }
}

extension PostComment {
    init(row: CommentRow) {
        id = row.id
        body = row.body
        createdAt = row.createdAt
        author = row.author
    }
}
