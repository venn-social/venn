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
    @Environment(AuthState.self)
    private var authState

    @State private var query = ""
    @State private var selectedCategory: ExplorerCategory = .all
    @State private var viewModel: ExplorerViewModel?
    @State private var composerViewModel: ComposerViewModel?
    @State private var peopleViewModel: PeopleSearchViewModel?
    @State private var recommendations: RecommendationsViewModel?

    var body: some View {
        NavigationStack {
            Screen {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        SearchField(text: $query, prompt: "Search movies, TV, music, books, people")
                        categoryPicker
                        if query.isEmpty {
                            if selectedCategory.browseKind != nil {
                                browseStack
                            } else if selectedCategory == .people {
                                peopleBrowsePrompt
                            } else {
                                recommendationsStack
                                allBrowsePrompt
                            }
                        } else if selectedCategory == .people {
                            peopleResultsStack
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
            .navigationDestination(for: UserProfile.self) { profile in
                PublicProfileView(profile: profile)
            }
            .navigationDestination(for: Media.self) { media in
                MediaDetailView(media: media)
            }
        }
        .task { await ensureLoaded() }
        .onChange(of: selectedCategory) { _, newCategory in
            if let kind = newCategory.browseKind {
                Task { await viewModel?.load(kind: kind) }
            }
            dispatchSearch(query: query, category: newCategory)
        }
        .onChange(of: query) { _, newQuery in
            dispatchSearch(query: newQuery, category: selectedCategory)
        }
    }

    /// Route the query to the right search engine for the category —
    /// profiles for People, the media catalog otherwise — and idle the one
    /// that's not in use so stale results don't flash on category switch.
    private func dispatchSearch(query: String, category: ExplorerCategory) {
        if category == .people {
            composerViewModel?.clearSearch()
            peopleViewModel?.search(query)
        } else {
            peopleViewModel?.clear()
            composerViewModel?.search(query, kinds: category.searchKinds)
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
            .frame(minWidth: 640)
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
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load recommendations") {
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
                NavigationLink(value: item) {
                    ExplorerMediaCell(media: item)
                }
                .buttonStyle(.plain)
                .vennScrollDepth()
            }
        }
    }

    /// Only in the "All" category with an empty query: shelves are for
    /// browsing, and leaving them above live search results would push what
    /// the user just typed off the screen.
    @ViewBuilder private var recommendationsStack: some View {
        if let recommendations {
            RecommendationsView(viewModel: recommendations) { candidate in
                composerViewModel?.pick(candidate)
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

    /// Shown in browse mode when the "People" category is selected.
    private var peopleBrowsePrompt: some View {
        EmptyStateView(
            systemImage: "person.2",
            title: "Find your people",
            message: "Search by name or username to see what they're into."
        )
    }

    // MARK: - People search mode

    @ViewBuilder private var peopleResultsStack: some View {
        if let vm = peopleViewModel {
            switch vm.state {
            case .idle:
                EmptyView()
            case .searching:
                DeferredLoadingView(caption: "Searching…")
            case let .results(profiles):
                if profiles.isEmpty {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "No one found",
                        message: "Try a different name or username."
                    )
                } else {
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(profiles) { profile in
                            NavigationLink(value: profile) {
                                ProfileRow(profile: profile)
                            }
                            .buttonStyle(.plain)
                            .vennScrollDepth()
                        }
                    }
                }
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Search failed")
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
                ErrorStateView(reason: reason, unknownTitle: "Search failed")
            }
        }
    }

    // MARK: - Composer sheet

    private var isComposerPresented: Binding<Bool> {
        Binding(
            get: { composerViewModel?.selectedCandidate != nil },
            set: {
                if !$0 {
                    composerViewModel?.clearPick()
                }
            }
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
        if recommendations == nil {
            let viewModel = RecommendationsViewModel(
                service: RecommendationService(client: clientProvider.client),
                catalog: CatalogSimilarService(tmdbAPIKey: config.tmdbAPIKey)
            )
            recommendations = viewModel
            await viewModel.load()
        }
        if peopleViewModel == nil {
            let currentUserID: UUID? = if case let .signedIn(session) = authState.status {
                session.user.id
            } else {
                nil
            }
            peopleViewModel = PeopleSearchViewModel(
                service: PeopleSearchService(client: clientProvider.client),
                currentUserID: currentUserID
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
            MediaCoverTile(title: media.title, kind: media.kind, coverURL: media.coverURL, height: 180)
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
