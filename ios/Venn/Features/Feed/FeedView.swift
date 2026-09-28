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

    /// Brief confirmation after a Log / Add to Watchlist from a row.
    /// Dismisses itself: it reports something already done, so there is
    /// nothing for the reader to act on.
    @ViewBuilder private var quickActionToast: some View {
        if let message = viewModel?.lastQuickActionMessage {
            Text(message)
                .font(Theme.Font.footnote.weight(.medium))
                .foregroundStyle(Theme.Color.onAccent)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Color.accent, in: .capsule)
                .padding(.bottom, Theme.Spacing.xxl)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("feed_quick_action_toast")
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation { viewModel?.lastQuickActionMessage = nil }
                }
        }
    }

    var body: some View {
        NavigationStack {
            content
                // The write lands on a screen the reader is not looking at,
                // so the confirmation is the only feedback there is.
                .overlay(alignment: .bottom) { quickActionToast }
                .toolbar(.hidden, for: .navigationBar)
                .containerBackground(for: .navigation) {
                    Theme.Color.background
                }
                .navigationDestination(for: Media.self) { media in
                    MediaDetailView(media: media)
                }
                // Feed rows now link their author. Without this the link
                // renders but goes nowhere.
                .navigationDestination(for: UserProfile.self) { profile in
                    PublicProfileView(profile: profile)
                }
                .navigationDestination(for: FeedPost.self) { feedPost in
                    if let viewerID = signedInUserID {
                        PostDetailView(
                            feedPost: feedPost,
                            viewerID: viewerID,
                            service: SocialService(client: clientProvider.client)
                        )
                    }
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
                        // The row is no longer one big link: the cover
                        // opens the title, and the comment tally opens the
                        // conversation. Matches web, and means a like no
                        // longer costs a screen transition.
                        post(feedPost, viewModel: viewModel)
                            .vennScrollDepth()
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

    /// One post: the card when there is somebody to like it, the bare row
    /// when there is not.
    ///
    /// Deliberately *not* given a fresh identity when the counts arrive:
    /// `FeedPostCardView` watches `info` and reseeds itself. Re-creating it
    /// would collapse an open comment thread and throw away the comments it
    /// had loaded, every time the counts landed or the feed refreshed.
    @ViewBuilder
    private func post(_ feedPost: FeedPost, viewModel: FeedViewModel) -> some View {
        if let viewerID = signedInUserID {
            FeedPostCardView(
                feedPost: feedPost,
                viewerID: viewerID,
                info: viewModel.social(for: feedPost.id).likes,
                commentCount: viewModel.social(for: feedPost.id).commentCount,
                service: SocialService(client: clientProvider.client)
            ) { action in
                Task {
                    await viewModel.performQuickAction(
                        action,
                        mediaID: feedPost.media.id,
                        viewerID: viewerID
                    )
                }
            }
        } else {
            FeedRow(feedPost: feedPost)
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
                service: FeedService(client: clientProvider.client),
                socialService: SocialService(client: clientProvider.client)
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
