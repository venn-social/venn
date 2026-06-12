import SwiftUI

/// Feed tab content. Loads recent posts from `FeedService` and renders
/// them as an image-forward stream of `FeedRow`s. Shows a loading spinner
/// during fetch, an empty state when there's nothing yet, and a retry-able
/// error state on failure. Same shape as `ProfileView`.
struct FeedView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var viewModel: FeedViewModel?

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
                    loadedView(posts: posts)
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

    private func loadedView(posts: [FeedPost]) -> some View {
        Screen {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                    ForEach(posts) { feedPost in
                        FeedRow(feedPost: feedPost)
                            .vennScrollDepth()
                    }
                }
                .padding(.top, Theme.Spacing.md)
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
}
