import SwiftUI

/// Explorer tab. Header-less and minimal, matching the refreshed Feed. Two
/// modes off the search field:
///   - **Browse** (empty query): recent media of the selected kind from
///     `ExplorerService`, as an image-forward cover grid. The "All" category
///     shows a search prompt instead.
///   - **Search** (non-empty query): live search against TMDB / OpenLibrary /
///     MusicBrainz via `ComposerViewModel`; tapping a result opens the
///     composer sheet to log or save the item.
///
/// The category picker controls both the browse kind and the search scope.
struct ExplorerView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @Environment(AppConfig.self)
    private var config

    @State private var query = ""
    @State private var selectedCategory: ExplorerCategory = .all
    @State private var viewModel: ExplorerViewModel?
    @State private var composerViewModel: ComposerViewModel?

    var body: some View {
        NavigationStack {
            Screen {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        SearchField(text: $query, prompt: "Search movies, TV, music, books")
                        categoryPicker
                        if query.isEmpty {
                            if selectedCategory.browseKind != nil {
                                browseStack
                            } else {
                                allBrowsePrompt
                            }
                        } else {
                            searchResultsStack
                        }
                    }
                    .padding(.top, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
                .scrollContentBackground(.hidden)
                .tracksGlassSkyParallax()
            }
            .toolbar(.hidden, for: .navigationBar)
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
            if let kind = newCategory.browseKind {
                Task { await viewModel?.load(kind: kind) }
            }
            if !query.isEmpty {
                composerViewModel?.search(query, kinds: newCategory.searchKinds)
            }
        }
        .onChange(of: query) { _, newQuery in
            composerViewModel?.search(newQuery, kinds: selectedCategory.searchKinds)
        }
    }

    // MARK: - Categories

    /// Wrapped in a horizontal ScrollView so all chips fit any screen width.
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassSegmentedControl(
                items: ExplorerCategory.allCases,
                selection: $selectedCategory,
                title: \.title,
                systemImage: \.icon
            )
            .frame(minWidth: 520)
        }
        .scrollClipDisabled()
    }

    // MARK: - Browse mode

    @ViewBuilder private var browseStack: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Looking for something good…")
            case let .loaded(media):
                if media.isEmpty {
                    browseEmptyView
                } else {
                    grid(media)
                }
            case let .error(reason):
                browseErrorView(reason: reason) {
                    if let kind = selectedCategory.browseKind {
                        Task { await viewModel.load(kind: kind) }
                    }
                }
            }
        }
    }

    private func grid(_ media: [Media]) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Theme.Spacing.md),
                GridItem(.flexible(), spacing: Theme.Spacing.md),
            ],
            spacing: Theme.Spacing.lg
        ) {
            ForEach(media) { item in
                ExplorerMediaCell(media: item)
                    .vennScrollDepth()
            }
        }
    }

    /// Shown in browse mode when the "All" category is selected.
    private var allBrowsePrompt: some View {
        EmptyStateView(
            systemImage: "magnifyingglass",
            title: "Search everything",
            message: "Type in the search bar to find movies, TV shows, music, and books all at once."
        )
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
            if let kind = selectedCategory.browseKind {
                await vm.load(kind: kind)
            }
        }
        if composerViewModel == nil {
            let tmdb = config.tmdbAPIKey.map { TMDBService(apiKey: $0) }
            composerViewModel = ComposerViewModel(
                service: ComposerService(tmdb: tmdb, client: clientProvider.client)
            )
        }
    }
}

/// One cover in the Explorer browse grid: an image-forward tile with the
/// title and creator beneath.
private struct ExplorerMediaCell: View {
    let media: Media

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            MediaCoverTile(title: media.title, kind: media.kind, height: 180)
            Text(media.title)
                .font(Theme.Font.callout.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)
                .lineLimit(2)
            if let creator = media.primaryCreator {
                Text(creator)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    ExplorerView()
        .environment(AppConfig.preview)
        .environment(SupabaseClientProvider.preview)
        .environment(AuthState(service: AuthService(client: SupabaseClientProvider.preview.client)))
}
