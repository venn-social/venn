import SwiftUI

/// A single post with its likes and comment thread — iOS's equivalent of
/// web's `/post/[id]` permalink. Copy matches web (CLAUDE.md rule 17).
struct PostDetailView: View {
    let feedPost: FeedPost
    let viewerID: UUID
    let service: any SocialServicing

    @State private var viewModel: PostDetailViewModel?
    @State private var draft = ""

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
                    ForEach(comments) { comment in
                        commentRow(comment, viewModel: viewModel)
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

    private func commentRow(_ comment: PostComment, viewModel: PostDetailViewModel) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(comment.author.displayName ?? comment.author.username)
                        .font(Theme.Font.footnote.weight(.medium))
                        .foregroundStyle(Theme.Color.textPrimary)
                    Text(RelativeTime.short(from: comment.createdAt))
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                Text(comment.body)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Spacing.sm)

            // Mirrors the RLS policy: your own comment anywhere, or anyone's
            // comment on your own post.
            if comment.author.id == viewerID || feedPost.post.authorID == viewerID {
                Button("Delete") {
                    Task { await viewModel.deleteComment(comment.id) }
                }
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
