import SwiftUI

/// A single post with its likes and comment thread — iOS's equivalent of
/// web's `/post/[id]` permalink. Copy matches web (CLAUDE.md rule 17).
///
/// The thread itself lives in `CommentThreadView`, which the feed renders
/// too. This screen remains the conversation's shareable address, and is
/// where notifications land.
struct PostDetailView: View {
    let feedPost: FeedPost
    let viewerID: UUID
    let service: any SocialServicing

    @State private var viewModel: PostDetailViewModel?

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

                    CommentThreadView(
                        viewModel: viewModel,
                        viewerID: viewerID,
                        postAuthorID: feedPost.post.authorID
                    )
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .navigationTitle("Post")
        .navigationBarTitleDisplayMode(.inline)
        .task { await ensureLoaded() }
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
