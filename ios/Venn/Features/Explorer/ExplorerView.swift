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
    @Environment(LanguageStore.self)
    private var languageStore
    @Environment(AuthState.self)
    private var authState

    @State private var query = ""
    @State private var selectedCategory: ExplorerCategory = .all
    @State private var path = NavigationPath()
    /// The candidate currently being turned into a catalog row, so its
    /// cell can show it is working rather than looking dead on tap.
    @State private var opening: String?
    @State private var composerViewModel: ComposerViewModel?
    @State private var peopleViewModel: PeopleSearchViewModel?
    @State private var recommendations: RecommendationsViewModel?

    var body: some View {
        NavigationStack(path: $path) {
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
                Theme.Color.background
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

    /// The per-kind tabs, which now answer the same question the All tab
    /// does. They used to list the newest rows in the catalog — what other
    /// people happened to log, which belongs on a profile, not here.
    @ViewBuilder private var browseStack: some View {
        if let recommendations, let kind = selectedCategory.browseKind {
            RecommendationsView(viewModel: recommendations, kind: kind) { candidate in
                open(candidate)
            }
        }
    }

    /// Only in the "All" category with an empty query: shelves are for
    /// browsing, and leaving them above live search results would push what
    /// the user just typed off the screen.
    @ViewBuilder private var recommendationsStack: some View {
        if let recommendations {
            RecommendationsView(viewModel: recommendations) { candidate in
                open(candidate)
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

    // MARK: - Opening a catalog result

    /// Open a catalog result on its detail page.
    ///
    /// Tapping a recommendation used to open the composer, which re-ran the
    /// search you had just done and made you pick the same thing again
    /// before you could read anything about it — two taps to answer "what
    /// is this", which is the first question. Mirrors web's
    /// `useOpenCandidate` (rule 17).
    ///
    /// A catalog result has no row in `public.media` yet and so no detail
    /// page to push, which is why it went to the composer at all.
    /// `upsertMedia` is what logging would call moments later anyway and is
    /// idempotent on (source, external id), so opening the same title twice
    /// does not duplicate it. If the write fails we fall back to the
    /// composer, which is the old behaviour and still better than a dead
    /// tap.
    private func open(_ candidate: MediaCandidate) {
        guard opening == nil, let composerViewModel else { return }
        opening = candidate.id

        Task {
            defer { opening = nil }
            do {
                let id = try await composerViewModel.upsertMedia(candidate)
                path.append(Media(
                    id: id,
                    kind: candidate.kind,
                    title: candidate.title,
                    year: candidate.year,
                    primaryCreator: candidate.primaryCreator,
                    coverURL: candidate.coverURL,
                    externalID: candidate.externalID,
                    externalSource: candidate.externalSource,
                    createdAt: Date()
                ))
            } catch {
                composerViewModel.pick(candidate)
            }
        }
    }

    // MARK: - Setup

    private func ensureLoaded() async {
        if composerViewModel == nil {
            let tmdb = config.tmdbAPIKey.map { TMDBService(apiKey: $0, language: languageStore.current) }
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
        .environment(LanguageStore())
}
