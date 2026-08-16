import Foundation

/// Drives `PostDetailView`: a post's likes and its comment thread.
///
/// Uses the shared `LoadState` machine rather than a per-feature enum
/// (docs/ARCHITECTURE.md, "The standard load pattern").
@Observable
@MainActor
final class PostDetailViewModel {
    private(set) var state: LoadState<[PostComment]> = .loading
    private(set) var likeInfo: LikeInfo = .none
    private(set) var submitting = false
    /// Set when a write fails; the view renders it inline and clears on retry.
    private(set) var errorMessage: String?

    private let postID: UUID
    private let service: any SocialServicing

    init(postID: UUID, service: any SocialServicing) {
        self.postID = postID
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            // Independent of each other, so they load together.
            async let comments = service.comments(postID: postID, limit: 100)
            async let info = service.likeInfo(postIDs: [postID])
            let (loadedComments, loadedInfo) = try await (comments, info)

            likeInfo = loadedInfo[postID] ?? .none
            state = .loaded(loadedComments)
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }

    /// `parentID` nil posts a root comment; otherwise a reply. The database
    /// refuses a reply to a reply, so callers do not check depth themselves.
    func addComment(body: String, authorID: UUID, parentID: UUID? = nil) async {
        guard case let .valid(clean) = Sanitize.caption(body) else {
            errorMessage = "Comments are 1–500 characters."
            return
        }

        submitting = true
        errorMessage = nil
        do {
            try await service.addComment(
                postID: postID,
                authorID: authorID,
                body: clean,
                parentID: parentID
            )
            await load()
        } catch let error as AppError {
            if case .rateLimited = error {
                errorMessage = "You're commenting very fast — give it a moment."
            } else {
                errorMessage = "Couldn't post that. Please try again."
            }
        } catch {
            errorMessage = "Couldn't post that. Please try again."
        }
        submitting = false
    }

    /// Optimistic, like delete: the new text shows immediately and a failed
    /// save reloads to put the original back.
    ///
    /// The marker is set here too, because the database sets it on the row
    /// and the reader should see the same thing straight away rather than
    /// only after the next load.
    func editComment(_ commentID: UUID, body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, case let .loaded(comments) = state else { return }

        state = .loaded(comments.map { comment in
            guard comment.id == commentID else { return comment }
            return PostComment(
                id: comment.id,
                body: trimmed,
                createdAt: comment.createdAt,
                editedAt: Date(),
                parentID: comment.parentID,
                author: comment.author
            )
        })

        do {
            try await service.editComment(commentID: commentID, body: trimmed)
        } catch {
            await load()
        }
    }

    /// Optimistic: the comment disappears immediately, and a failed delete
    /// puts it back by reloading — the same shape `FollowRequestsViewModel`
    /// uses for accept/reject.
    func deleteComment(_ commentID: UUID) async {
        guard case let .loaded(comments) = state else { return }
        state = .loaded(comments.filter { $0.id != commentID })

        do {
            try await service.deleteComment(commentID: commentID)
        } catch {
            await load()
        }
    }
}
