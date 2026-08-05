import Foundation
import Testing
@testable import Venn

/// Hand-rolled fake — we don't mock Supabase (ADR 0005).
private actor FakeSocialService: SocialServicing {
    var comments: [PostComment] = []
    var info: LikeInfo = .none
    var loadError: (any Error)?
    var writeError: (any Error)?
    private(set) var addedBodies: [String] = []
    private(set) var deletedIDs: [UUID] = []

    func seed(comments: [PostComment] = [], info: LikeInfo = .none) {
        self.comments = comments
        self.info = info
    }

    func failLoad(with error: any Error) {
        loadError = error
    }

    func failWrite(with error: any Error) {
        writeError = error
    }

    func likeInfo(postIDs: [UUID]) async throws -> [UUID: LikeInfo] {
        if let loadError {
            throw loadError
        }
        guard let first = postIDs.first else { return [:] }
        return [first: info]
    }

    func like(postID _: UUID, userID _: UUID) async throws {}
    func unlike(postID _: UUID, userID _: UUID) async throws {}

    func comments(postID _: UUID, limit _: Int) async throws -> [PostComment] {
        if let loadError {
            throw loadError
        }
        return comments
    }

    func addComment(postID _: UUID, authorID _: UUID, body: String) async throws {
        if let writeError {
            throw writeError
        }
        addedBodies.append(body)
        comments.append(
            PostComment(id: UUID(), body: body, createdAt: Date(), author: Self.author)
        )
    }

    func deleteComment(commentID: UUID) async throws {
        if let writeError {
            throw writeError
        }
        deletedIDs.append(commentID)
        comments.removeAll { $0.id == commentID }
    }

    func commentCounts(postIDs _: [UUID]) async throws -> [UUID: Int] {
        [:]
    }

    static let author = UserProfile(
        id: UUID(),
        username: "ada",
        displayName: "Ada",
        avatarURL: nil,
        bio: nil,
        createdAt: Date()
    )
}

@Suite("PostDetailViewModel")
@MainActor
struct PostDetailViewModelTests {
    private func comment(_ body: String) -> PostComment {
        PostComment(id: UUID(), body: body, createdAt: Date(), author: FakeSocialService.author)
    }

    @Test("loads comments and like info together")
    func loadsBoth() async {
        let service = FakeSocialService()
        await service.seed(
            comments: [comment("First")],
            info: LikeInfo(likeCount: 2, likedByMe: true)
        )
        let model = PostDetailViewModel(postID: UUID(), service: service)

        await model.load()

        if case let .loaded(loaded) = model.state {
            #expect(loaded.map(\.body) == ["First"])
        } else {
            Issue.record("expected a loaded state")
        }
        #expect(model.likeInfo.likeCount == 2)
        #expect(model.likeInfo.likedByMe == true)
    }

    @Test("a post with no likes falls back to none rather than nil")
    func defaultsLikeInfo() async {
        let service = FakeSocialService()
        await service.seed(comments: [], info: .none)
        let model = PostDetailViewModel(postID: UUID(), service: service)

        await model.load()

        #expect(model.likeInfo == .none)
    }

    @Test("a load failure surfaces as an error state")
    func loadFailure() async {
        let service = FakeSocialService()
        await service.failLoad(with: AppError.network)
        let model = PostDetailViewModel(postID: UUID(), service: service)

        await model.load()

        #expect(model.state == .error(.offline))
    }

    @Test("rejects a comment that fails validation without calling the service")
    func rejectsEmptyComment() async {
        let service = FakeSocialService()
        let model = PostDetailViewModel(postID: UUID(), service: service)
        await model.load()

        await model.addComment(body: "   ", authorID: UUID())

        #expect(model.errorMessage != nil)
        #expect(await service.addedBodies.isEmpty)
    }

    @Test("a rate-limited comment says to wait, not to retry")
    func rateLimitedComment() async {
        // Retrying is the one thing that doesn't help, so the copy must
        // differ from a generic failure.
        let service = FakeSocialService()
        await service.failWrite(with: AppError.rateLimited)
        let model = PostDetailViewModel(postID: UUID(), service: service)
        await model.load()

        await model.addComment(body: "Nice", authorID: UUID())

        #expect(model.errorMessage?.contains("give it a moment") == true)
    }

    @Test("deleting a comment removes it immediately")
    func deleteIsOptimistic() async {
        let service = FakeSocialService()
        let existing = comment("Gone soon")
        await service.seed(comments: [existing])
        let model = PostDetailViewModel(postID: UUID(), service: service)
        await model.load()

        await model.deleteComment(existing.id)

        if case let .loaded(remaining) = model.state {
            #expect(remaining.isEmpty)
        } else {
            Issue.record("expected a loaded state after delete")
        }
    }
}
