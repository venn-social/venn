import SwiftUI

/// A single post with its likes and comment thread — iOS's equivalent of
/// web's `/post/[id]` permalink. Copy matches web (CLAUDE.md rule 17).
struct PostDetailView: View {
    let feedPost: FeedPost
    let viewerID: UUID
    let service: any SocialServicing

    @State private var viewModel: PostDetailViewModel?
    @State private var draft = ""
    /// The comment being edited, and its working text. Separate from
    /// `draft` so opening an edit does not swallow a half-written comment.
    @State private var editingID: UUID?
    @State private var editDraft = ""
    /// The comment being replied to, and the reply text. Separate from the
    /// edit and composer drafts so opening one does not swallow another.
    @State private var replyingTo: UUID?
    @State private var replyDraft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                FeedRow(feedPost: feedPost)

                if let viewModel {
                    PostActionsView(
                        postID: feedPost.post.id,
                        userID: viewerID,
                        info: viewModel.likeInfo,
                        commentCount: commentCount(viewModel),
                        service: service
                    )

                    Divider()
                    commentSection(viewModel)
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await ensureLoaded() }
    }

    @ViewBuilder
    private func commentSection(_ viewModel: PostDetailViewModel) -> some View {
        switch viewModel.state {
        case .loading:
            DeferredLoadingView(caption: "Loading comments…")
        case let .loaded(comments):
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(heading(for: comments.count))
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Color.textPrimary)

                if comments.isEmpty {
                    Text("No comments yet. Say something.")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Color.textSecondary)
                } else {
                    ForEach(PostComment.threads(from: comments)) { thread in
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            commentRow(thread.comment, viewModel: viewModel, isReply: false)

                            if replyingTo == thread.comment.id {
                                replyEditor(thread.comment, viewModel: viewModel)
                                    .padding(.leading, Theme.Spacing.xxl)
                            }

                            ForEach(thread.replies) { reply in
                                commentRow(reply, viewModel: viewModel, isReply: true)
                                    .padding(.leading, Theme.Spacing.xxl)
                            }
                        }
                    }
                }

                composer(viewModel)
            }
        case let .error(reason):
            ErrorStateView(reason: reason, unknownTitle: "Couldn't load comments") {
                Task { await viewModel.load() }
            }
        }
    }

    private func commentRow(
        _ comment: PostComment,
        viewModel: PostDetailViewModel,
        isReply: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(comment.author.displayName ?? comment.author.username)
                        .font(Theme.Font.footnote.weight(.medium))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(RelativeTime.short(from: comment.createdAt))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    if comment.editedAt != nil {
                        Text("(edited)")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                            .accessibilityIdentifier("comment_edited_marker")
                    }
                }

                if editingID == comment.id {
                    commentEditor(comment, viewModel: viewModel)
                } else {
                    Text(comment.body)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: Theme.Spacing.sm)

            // Mirrors the RLS policy: your own comment anywhere, or anyone's
            // comment on your own post.
            if editingID != comment.id {
                HStack(spacing: Theme.Spacing.md) {
                    if !isReply {
                        Button("Reply") {
                            replyDraft = ""
                            replyingTo = comment.id
                        }
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    }

                    // Editing is the author's alone. Removing someone's
                    // comment from your own post is moderation; rewriting it
                    // is impersonation, so the post's author does not get it.
                    if comment.author.id == viewerID {
                        Button("Edit") {
                            editDraft = comment.body
                            editingID = comment.id
                        }
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    }

                    if comment.author.id == viewerID || feedPost.post.authorID == viewerID {
                        Button("Delete") {
                            Task { await viewModel.deleteComment(comment.id) }
                        }
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                    }
                }
            }
        }
    }

    private func replyEditor(
        _ parent: PostComment,
        viewModel: PostDetailViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            TextField("Write a reply", text: $replyDraft, axis: .vertical)
                .font(Theme.Font.callout)
                .lineLimit(1...6)
                .padding(Theme.Spacing.sm)
                .background(
                    Theme.Color.surfaceStrong,
                    in: .rect(cornerRadius: Theme.Radius.sm)
                )
                .accessibilityIdentifier("comment_reply_field")

            HStack(spacing: Theme.Spacing.md) {
                Button("Reply") {
                    let text = replyDraft
                    replyingTo = nil
                    replyDraft = ""
                    Task {
                        await viewModel.addComment(
                            body: text,
                            authorID: viewerID,
                            parentID: parent.id
                        )
                    }
                }
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.Color.accent)
                .disabled(replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Cancel") { replyingTo = nil }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }

    private func commentEditor(
        _ comment: PostComment,
        viewModel: PostDetailViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            TextField("Edit your comment", text: $editDraft, axis: .vertical)
                .font(Theme.Font.callout)
                .lineLimit(1...6)
                .padding(Theme.Spacing.sm)
                .background(
                    Theme.Color.surfaceStrong,
                    in: .rect(cornerRadius: Theme.Radius.sm)
                )
                .accessibilityIdentifier("comment_edit_field")

            HStack(spacing: Theme.Spacing.md) {
                Button("Save") {
                    let text = editDraft
                    editingID = nil
                    Task { await viewModel.editComment(comment.id, body: text) }
                }
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.Color.accent)
                .disabled(
                    editDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || editDraft == comment.body
                )

                Button("Cancel") { editingID = nil }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }

    private func composer(_ viewModel: PostDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            TextField("Add a comment", text: $draft, axis: .vertical)
                .lineLimit(2...4)
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.md))

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.red)
            }

            Button("Post") {
                Task {
                    await viewModel.addComment(body: draft, authorID: viewerID)
                    if viewModel.errorMessage == nil {
                        draft = ""
                    }
                }
            }
            .disabled(viewModel.submitting || draft.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func heading(for count: Int) -> String {
        switch count {
        case 0: "Comments"
        case 1: "1 comment"
        default: "\(count) comments"
        }
    }

    private func commentCount(_ viewModel: PostDetailViewModel) -> Int {
        if case let .loaded(comments) = viewModel.state {
            return comments.count
        }
        return 0
    }

    private func ensureLoaded() async {
        if viewModel == nil {
            let model = PostDetailViewModel(postID: feedPost.post.id, service: service)
            viewModel = model
            await model.load()
        }
    }
}
