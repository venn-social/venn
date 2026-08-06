import SwiftUI

/// Loads one post by id, then shows it.
///
/// Exists because a notification carries a post id and `PostDetailView`
/// wants a whole `FeedPost`. Web gets this free — `/post/[id]` fetches on
/// the server — so this is the iOS shape of the same screen, not a
/// different one.
///
/// A missing post is a real outcome, not an error: notifications outlive
/// the posts that caused them, and RLS can hide a post whose author has
/// since gone private.
struct PostPermalinkView: View {
    let postID: UUID

    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @Environment(AuthState.self)
    private var authState

    @State private var state: LoadState<FeedPost?> = .loading

    private var viewerID: UUID? {
        if case let .signedIn(session) = authState.status {
            session.user.id
        } else {
            nil
        }
    }

    var body: some View {
        content
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            DeferredLoadingView(caption: "Loading the post…")
        case let .loaded(post):
            if let post, let viewerID {
                PostDetailView(
                    feedPost: post,
                    viewerID: viewerID,
                    service: SocialService(client: clientProvider.client)
                )
            } else {
                Screen {
                    EmptyStateView(
                        systemImage: "questionmark.circle",
                        title: "Post unavailable",
                        message: "It may have been deleted, or the account may be private."
                    )
                }
            }
        case let .error(reason):
            Screen {
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load the post") {
                    Task { await load() }
                }
            }
        }
    }

    private func load() async {
        guard case .loading = state else { return }
        do {
            let service = PostLookupService(client: clientProvider.client)
            state = try await .loaded(service.post(id: postID))
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }
}
