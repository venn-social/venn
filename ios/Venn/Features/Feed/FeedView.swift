import SwiftUI

/// Feed tab content. Loads recent posts from `FeedService` and renders
/// them as a stack of `ActivityCard`s. Shows a loading spinner during
/// fetch, an empty state when there's nothing yet, and a retry-able
/// error state on failure. Same shape as `ProfileView`.
struct FeedView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var viewModel: FeedViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Feed")
                .navigationBarTitleDisplayMode(.inline)
                .containerBackground(for: .navigation) {
                    GlassSkyBackground()
                }
        }
        .task { await ensureLoaded() }
    }

    @ViewBuilder private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading the feed…")
            case let .loaded(posts):
                if posts.isEmpty {
                    emptyView
                } else {
                    loadedView(posts: posts)
                }
            case let .error(reason):
                errorView(reason: reason) { Task { await viewModel.load() } }
            }
        } else {
            LoadingView()
        }
    }

    private func loadedView(posts: [FeedPost]) -> some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text("Today")
                        .font(Theme.Font.largeTitle)
                        .foregroundStyle(Theme.Color.textPrimary)

                    VStack(spacing: Theme.Spacing.md) {
                        ForEach(posts) { feedPost in
                            ActivityCard(
                                name: feedPost.author.displayName ?? feedPost.author.username,
                                action: feedPost.post.action.rawValue,
                                title: feedPost.media.title,
                                detail: feedPost.post.caption ?? "",
                                rating: feedPost.post.rating.map { String(format: "%.1f", $0) }
                            )
                            .vennScrollDepth()
                        }
                    }
                }
                .padding(.vertical, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .scrollContentBackground(.hidden)
            .tracksGlassSkyParallax()
        }
    }

    private var emptyView: some View {
        Screen {
            EmptyStateView(
                systemImage: "square.stack.3d.up",
                title: "Quiet for now",
                message: "Posts from people you follow will land here once they start logging."
            )
        }
    }

    private func errorView(
        reason: FeedViewModel.ErrorReason,
        retry: @escaping () -> Void
    ) -> some View {
        Screen {
            EmptyStateView(
                systemImage: reason == .offline ? "wifi.slash" : "exclamationmark.triangle",
                title: reason == .offline ? "You're offline" : "Couldn't load the feed",
                message: reason == .offline
                    ? "Reconnect to see the latest posts."
                    : "Something went wrong on our end. Try again in a moment.",
                actionTitle: "Try again",
                action: retry
            )
        }
    }

    private func ensureLoaded() async {
        if viewModel == nil {
            let viewModel = FeedViewModel(
                service: FeedService(client: clientProvider.client)
            )
            self.viewModel = viewModel
            await viewModel.load()
        }
    }
}

#Preview {
    FeedView()
        .environment(SupabaseClientProvider.preview)
}
