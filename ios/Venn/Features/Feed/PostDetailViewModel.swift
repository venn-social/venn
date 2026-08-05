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

    func addComment(body: String, authorID: UUID) async {
        guard case let .valid(clean) = Sanitize.caption(body) else {
            errorMessage = "Comments are 1–500 characters."
            return
        }

        submitting = true
        errorMessage = nil
        do {
            try await service.addComment(postID: postID, authorID: authorID, body: clean)
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
