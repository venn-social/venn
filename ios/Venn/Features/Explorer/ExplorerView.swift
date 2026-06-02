import SwiftUI

/// Explorer tab. Loads recent media of the selected kind from
/// `ExplorerService` and renders them as a stack of recommendation
/// cards. Reloads when the user switches the category picker. Search
/// is decorative for now — wiring full-text search needs Postgres
/// `tsvector` infra that hasn't landed yet.
struct ExplorerView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var query = ""
    @State private var selectedCategory: ExplorerCategory = .movies
    @State private var viewModel: ExplorerViewModel?

    var body: some View {
        NavigationStack {
            Screen {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        header
                        categoryPicker
                        recommendationStack
                        quickActions
                    }
                    .padding(.vertical, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
                .scrollContentBackground(.hidden)
                .tracksGlassSkyParallax()
            }
            .navigationTitle("Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Search movies, music, books"))
            .containerBackground(for: .navigation) {
                GlassSkyBackground()
            }
        }
        .task { await ensureLoaded() }
        .onChange(of: selectedCategory) { _, newCategory in
            Task { await viewModel?.load(kind: newCategory.mediaKind) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Explorer")
                .font(Theme.Font.largeTitle)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("Search what you know, find what to try next, and save it to your profile.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private var categoryPicker: some View {
        GlassSegmentedControl(
            items: ExplorerCategory.allCases,
            selection: $selectedCategory,
            title: \.title,
            systemImage: \.icon
        )
    }

    private var recommendationStack: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recommended for you")
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)

            if let viewModel {
                switch viewModel.state {
                case .loading:
                    DeferredLoadingView(caption: "Looking for something good…")
                case let .loaded(media):
                    if media.isEmpty {
                        emptyView
                    } else {
                        loadedList(media)
                    }
                case let .error(reason):
                    errorView(reason: reason) {
                        Task { await viewModel.load(kind: selectedCategory.mediaKind) }
                    }
                }
            }
        }
    }

    private func loadedList(_ media: [Media]) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(media) { item in
                ExplorerRecommendationCard(media: item, category: selectedCategory)
                    .vennScrollDepth()
            }
        }
    }

    private var emptyView: some View {
        EmptyStateView(
            systemImage: "magnifyingglass",
            title: "Nothing here yet",
            message: "We don't have any \(selectedCategory.title.lowercased()) in the catalog yet."
        )
    }

    private func errorView(
        reason: ExplorerViewModel.ErrorReason,
        retry: @escaping () -> Void
    ) -> some View {
        EmptyStateView(
            systemImage: reason == .offline ? "wifi.slash" : "exclamationmark.triangle",
            title: reason == .offline ? "You're offline" : "Couldn't load recommendations",
            message: reason == .offline
                ? "Reconnect to see what's new."
                : "Something went wrong. Try again in a moment.",
            actionTitle: "Try again",
            action: retry
        )
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ExplorerActionRow(
                icon: "checkmark.circle",
                title: "Add to watched",
                detail: "Keep a permanent record of what you consumed."
            )
            .vennScrollDepth()
            ExplorerActionRow(
                icon: "bookmark",
                title: "Save to watchlist",
                detail: "A softer maybe list for later."
            )
            .vennScrollDepth()
        }
    }

    private func ensureLoaded() async {
        if viewModel == nil {
            let viewModel = ExplorerViewModel(
                service: ExplorerService(client: clientProvider.client)
            )
            self.viewModel = viewModel
            await viewModel.load(kind: selectedCategory.mediaKind)
        }
    }
}

#Preview {
    ExplorerView()
        .environment(SupabaseClientProvider.preview)
}
