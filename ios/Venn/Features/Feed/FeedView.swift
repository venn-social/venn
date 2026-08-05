import SwiftUI

/// Feed tab content. Loads recent posts from `FeedService` and renders
/// them as an image-forward stream of `FeedRow`s. Shows a loading spinner
/// during fetch, an empty state when there's nothing yet, and a retry-able
/// error state on failure. Same shape as `ProfileView`.
struct FeedView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @Environment(AuthState.self)
    private var authState

    @State private var viewModel: FeedViewModel?

    /// The viewer, for likes and comments on the post detail screen.
    private var signedInUserID: UUID? {
        if case let .signedIn(session) = authState.status {
            session.user.id
        } else {
            nil
        }
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(.hidden, for: .navigationBar)
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
                    loadedView(posts: posts, viewModel: viewModel)
                }
            case let .error(reason):
                Screen {
                    ErrorStateView(reason: reason, unknownTitle: "Couldn't load the feed") {
                        Task { await viewModel.load() }
                    }
                }
            }
        } else {
            DeferredLoadingView()
        }
    }

    private func loadedView(posts: [FeedPost], viewModel: FeedViewModel) -> some View {
        Screen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    ForEach(posts) { feedPost in
                        // Tapping through to the permalink is how likes and
                        // comments are reached — the row itself stays a
                        // presentation-only view.
                        if let viewerID = signedInUserID {
                            NavigationLink {
                                PostDetailView(
                                    feedPost: feedPost,
                                    viewerID: viewerID,
                                    service: SocialService(client: clientProvider.client)
                                )
                            } label: {
                                FeedRow(feedPost: feedPost)
                            }
                            .buttonStyle(.plain)
                            .vennScrollDepth()
                        } else {
                            FeedRow(feedPost: feedPost)
                                .vennScrollDepth()
                        }
                    }
                    // Lazy footer: appears only when scrolled to, so its
                    // .task IS the infinite-scroll trigger. Hidden once the
                    // feed is exhausted (hasMore == false).
                    if viewModel.hasMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.Spacing.lg)
                            .task { await viewModel.loadMore() }
                    }
                }
                .padding(.top, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xxxl)
            }
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.refresh() }
            .tracksGlassSkyParallax()
        }
    }

    private var emptyView: some View {
        Screen {
            EmptyStateView(
                systemImage: "square.stack.3d.up",
                title: "Quiet for now",
                message: "Your feed shows people you follow. Find them under People in the Explorer tab — or log something yourself."
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
        .environment(
            AuthState(service: AuthService(client: SupabaseClientProvider.preview.client))
        )
}
