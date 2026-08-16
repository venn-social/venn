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
    /// Parents for each added comment, so a test can prove a reply is a reply.
    private(set) var addedParents: [UUID?] = []
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

    func addComment(
        postID _: UUID,
        authorID _: UUID,
        body: String,
        parentID: UUID?
    ) async throws {
        if let writeError {
            throw writeError
        }
        addedBodies.append(body)
        addedParents.append(parentID)
        comments.append(
            PostComment(
                id: UUID(),
                body: body,
                createdAt: Date(),
                editedAt: nil,
                parentID: parentID,
                author: Self.author
            )
        )
    }

    private(set) var edited: [(id: UUID, body: String)] = []

    func editComment(commentID: UUID, body: String) async throws {
        if let writeError {
            throw writeError
        }
        edited.append((commentID, body))
        comments = comments.map { comment in
            guard comment.id == commentID else { return comment }
            return PostComment(
                id: comment.id,
                body: body,
                createdAt: comment.createdAt,
                editedAt: Date(),
                parentID: comment.parentID,
                author: comment.author
            )
        }
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
    private func comment(
        _ body: String,
        id: UUID = UUID(),
        createdAt: Date = Date(),
        parentID: UUID? = nil
    ) -> PostComment {
        PostComment(
            id: id,
            body: body,
            createdAt: createdAt,
            editedAt: nil,
            parentID: parentID,
            author: FakeSocialService.author
        )
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

    @Test("editing shows the new text and the marker immediately")
    func editIsOptimisticAndMarked() async {
        let service = FakeSocialService()
        await service.seed(comments: [comment("frist")])
        let viewModel = PostDetailViewModel(postID: UUID(), service: service)
        await viewModel.load()

        guard case let .loaded(before) = viewModel.state, let target = before.first else {
            Issue.record("expected a loaded comment")
            return
        }
        #expect(target.editedAt == nil)

        await viewModel.editComment(target.id, body: "first")

        guard case let .loaded(after) = viewModel.state, let edited = after.first else {
            Issue.record("expected a loaded comment")
            return
        }
        #expect(edited.body == "first")
        // The database stamps this; showing it straight away means the
        // reader sees the same thing everyone else will.
        #expect(edited.editedAt != nil)
    }

    @Test("an edit is trimmed before it is sent")
    func editTrimsWhitespace() async {
        let service = FakeSocialService()
        await service.seed(comments: [comment("original")])
        let viewModel = PostDetailViewModel(postID: UUID(), service: service)
        await viewModel.load()

        guard case let .loaded(before) = viewModel.state, let target = before.first else {
            Issue.record("expected a loaded comment")
            return
        }
        await viewModel.editComment(target.id, body: "  tidied  ")

        let sent = await service.edited
        #expect(sent.count == 1)
        #expect(sent.first?.body == "tidied")
    }

    @Test("an empty edit is not sent, since it would blank the comment")
    func emptyEditIsIgnored() async {
        let service = FakeSocialService()
        await service.seed(comments: [comment("original")])
        let viewModel = PostDetailViewModel(postID: UUID(), service: service)
        await viewModel.load()

        guard case let .loaded(before) = viewModel.state, let target = before.first else {
            Issue.record("expected a loaded comment")
            return
        }
        await viewModel.editComment(target.id, body: "   ")

        let sent = await service.edited
        #expect(sent.isEmpty)
    }

    @Test("a failed edit restores the original text")
    func failedEditReloads() async {
        // Leaving the optimistic text on screen would tell the author their
        // correction saved when it did not.
        let service = FakeSocialService()
        await service.seed(comments: [comment("original")])
        let viewModel = PostDetailViewModel(postID: UUID(), service: service)
        await viewModel.load()

        guard case let .loaded(before) = viewModel.state, let target = before.first else {
            Issue.record("expected a loaded comment")
            return
        }
        await service.failWrite(with: AppError.network)
        await viewModel.editComment(target.id, body: "never lands")

        guard case let .loaded(after) = viewModel.state else {
            Issue.record("expected a loaded state")
            return
        }
        #expect(after.first?.body == "original")
    }
}

/// Grouping a flat fetch into threads. Mirrors web's `toThreads` tests case
/// for case — a conversation must read the same on both platforms.
struct CommentThreadingTests {
    private func at(_ id: String, minute: Int, parent: UUID? = nil) -> PostComment {
        PostComment(
            id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", abs(id.hashValue % 1_000_000)))")
                ?? UUID(),
            body: id,
            createdAt: Date(timeIntervalSince1970: TimeInterval(minute * 60)),
            editedAt: nil,
            parentID: parent,
            author: FakeSocialService.author
        )
    }

    @Test("replies group under their root, oldest first")
    func groupsReplies() {
        let root = at("root", minute: 0)
        let later = at("b", minute: 2, parent: root.id)
        let earlier = at("a", minute: 1, parent: root.id)

        let threads = PostComment.threads(from: [root, later, earlier])

        #expect(threads.count == 1)
        #expect(threads[0].replies.map(\.body) == ["a", "b"])
    }

    @Test("roots read oldest first, like the conversation happened")
    func ordersRoots() {
        let threads = PostComment.threads(from: [at("second", minute: 5), at("first", minute: 1)])
        #expect(threads.map(\.comment.body) == ["first", "second"])
    }

    @Test("a root with no replies is left alone")
    func soloRoot() {
        let threads = PostComment.threads(from: [at("solo", minute: 0)])
        #expect(threads[0].replies.isEmpty)
    }

    @Test("a reply whose root is missing is promoted, not dropped")
    func orphanSurvives() {
        // Happens when a thread is paginated. Losing someone's words is worse
        // than showing them slightly out of place.
        let threads = PostComment.threads(from: [at("orphan", minute: 3, parent: UUID())])
        #expect(threads.map(\.comment.body) == ["orphan"])
    }

    @Test("a reply is never nested under another reply")
    func noSecondLevel() {
        // The database refuses this, but the grouping must not invent it
        // either if a row ever arrives that way.
        let root = at("root", minute: 0)
        let reply = at("a", minute: 1, parent: root.id)
        let deep = at("b", minute: 2, parent: reply.id)

        let threads = PostComment.threads(from: [root, reply, deep])

        #expect(threads[0].replies.map(\.body) == ["a"])
        #expect(threads.map(\.comment.body) == ["root", "b"])
    }

    @Test("no comments makes no threads")
    func empty() {
        #expect(PostComment.threads(from: []).isEmpty)
    }
}

@MainActor
struct CommentReplyPostingTests {
    @Test("a reply is sent as a reply, not as a new root comment")
    func replyCarriesItsParent() async {
        // Dropping the parent would post a reply that reads as an unrelated
        // remark — exactly the problem threading exists to fix.
        let service = FakeSocialService()
        let viewModel = PostDetailViewModel(postID: UUID(), service: service)
        let parent = UUID()

        await viewModel.addComment(body: "answering you", authorID: UUID(), parentID: parent)

        let parents = await service.addedParents
        #expect(parents == [parent])
    }

    @Test("a root comment carries no parent")
    func rootHasNoParent() async {
        let service = FakeSocialService()
        let viewModel = PostDetailViewModel(postID: UUID(), service: service)

        await viewModel.addComment(body: "first", authorID: UUID())

        let parents = await service.addedParents
        #expect(parents == [nil])
    }
}
