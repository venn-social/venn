import SwiftUI

/// Explorer tab. Two modes:
///   - **Browse:** loads recent media from Supabase and renders recommendation cards.
///   - **Search:** live search against TMDB / OpenLibrary / MusicBrainz. Tapping
///     a result opens the composer sheet so the user can log the item.
///
/// The category picker controls both the recommendation kind and the search scope.
struct ExplorerView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @Environment(AppConfig.self)
    private var config

    @State private var query = ""
    @State private var selectedCategory: ExplorerCategory = .movies
    @State private var viewModel: ExplorerViewModel?
    @State private var composerViewModel: ComposerViewModel?

    var body: some View {
        NavigationStack {
            Screen {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        header
                        categoryPicker
                        if query.isEmpty {
                            recommendationStack
                            quickActions
                        } else {
                            searchResultsStack
                        }
                    }
                    .padding(.vertical, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
                .scrollContentBackground(.hidden)
                .tracksGlassSkyParallax()
            }
            .navigationTitle("Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Search movies, music, books…"))
            .containerBackground(for: .navigation) {
                GlassSkyBackground()
            }
            .sheet(isPresented: isComposerPresented) {
                if let vm = composerViewModel {
                    ComposerSheetView(viewModel: vm)
                }
            }
        }
        .task { await ensureLoaded() }
        .onChange(of: selectedCategory) { _, newCategory in
            Task { await viewModel?.load(kind: newCategory.mediaKind) }
            if !query.isEmpty {
                composerViewModel?.search(query, kind: newCategory.mediaKind)
            }
        }
        .onChange(of: query) { _, newQuery in
            composerViewModel?.search(newQuery, kind: selectedCategory.mediaKind)
        }
    }

    // MARK: - Browse mode

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
                        browseEmptyView
                    } else {
                        VStack(spacing: Theme.Spacing.md) {
                            ForEach(media) { item in
                                ExplorerRecommendationCard(media: item, category: selectedCategory)
                                    .vennScrollDepth()
                            }
                        }
                    }
                case let .error(reason):
                    browseErrorView(reason: reason) {
                        Task { await viewModel.load(kind: selectedCategory.mediaKind) }
                    }
                }
            }
        }
    }

    private var browseEmptyView: some View {
        EmptyStateView(
            systemImage: "magnifyingglass",
            title: "Nothing here yet",
            message: "We don't have any \(selectedCategory.title.lowercased()) in the catalog yet."
        )
    }

    private func browseErrorView(
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

    // MARK: - Search mode

    @ViewBuilder private var searchResultsStack: some View {
        if let vm = composerViewModel {
            switch vm.searchState {
            case .idle:
                EmptyView()
            case .searching:
                DeferredLoadingView(caption: "Searching…")
            case let .results(candidates):
                if candidates.isEmpty {
                    EmptyStateView(
                        systemImage: "magnifyingglass",
                        title: "No results",
                        message: "Try a different search or switch categories."
                    )
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(candidates) { candidate in
                            ExplorerSearchResultRow(candidate: candidate) {
                                vm.pick(candidate)
                            }
                            .vennScrollDepth()
                        }
                    }
                }
            case let .error(reason):
                EmptyStateView(
                    systemImage: reason == .offline ? "wifi.slash" : "exclamationmark.triangle",
                    title: reason == .offline ? "You're offline" : "Search failed",
                    message: reason == .offline
                        ? "Reconnect to search."
                        : "Something went wrong. Try again."
                )
            }
        }
    }

    // MARK: - Composer sheet

    private var isComposerPresented: Binding<Bool> {
        Binding(
            get: { composerViewModel?.selectedCandidate != nil },
            set: { if !$0 { composerViewModel?.clearPick() } }
        )
    }

    // MARK: - Setup

    private func ensureLoaded() async {
        if viewModel == nil {
            let vm = ExplorerViewModel(service: ExplorerService(client: clientProvider.client))
            viewModel = vm
            await vm.load(kind: selectedCategory.mediaKind)
        }
        if composerViewModel == nil {
            let tmdb = config.tmdbAPIKey.map { TMDBService(apiKey: $0) }
            composerViewModel = ComposerViewModel(
                service: ComposerService(tmdb: tmdb, client: clientProvider.client)
            )
        }
    }
}

#Preview {
    ExplorerView()
        .environment(AppConfig.preview)
        .environment(SupabaseClientProvider.preview)
        .environment(AuthState(service: AuthService(client: SupabaseClientProvider.preview.client)))
        .environment(AppearanceSettings())
}
