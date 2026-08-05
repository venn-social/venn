import SwiftUI

/// Everything worth knowing about one title. Reached by tapping a title
/// anywhere — the feed, a profile shelf, Explorer, or a list — and mirrors
/// web's `/media/[id]` in copy and layout (CLAUDE.md rule 17).
///
/// The header renders from our own `media` row, so the screen is useful
/// the instant it opens and stays useful when a provider is unreachable.
/// Only the enriched sections below it wait on the network.
struct MediaDetailView: View {
    let media: Media

    @Environment(AppConfig.self)
    private var config
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var viewModel: MediaDetailViewModel?
    @State private var composerViewModel: ComposerViewModel?

    var body: some View {
        Screen(padding: EdgeInsets()) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    MediaDetailHeader(
                        media: media,
                        detail: loadedDetail ?? .empty,
                        onLog: logAction
                    )

                    enrichedSections
                }
                .padding(Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.xxl)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(media.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: isComposerPresented) {
            if let composerViewModel {
                ComposerSheetView(viewModel: composerViewModel)
            }
        }
        .task { await ensureLoaded() }
    }

    @ViewBuilder private var enrichedSections: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading the details…")
            case let .loaded(detail):
                loadedSections(detail)
            case let .error(reason):
                // The header is already on screen, so this replaces the
                // extra detail only — never the page.
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load the details") {
                    Task { await viewModel.load() }
                }
            }
        }
    }

    @ViewBuilder
    private func loadedSections(_ detail: MediaDetail) -> some View {
        if let overview = detail.overview, !overview.isEmpty {
            MediaDetailSection(title: "About") {
                Text(overview)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        MediaWatchLinksView(
            links: detail.watchLinks,
            regionName: detail.watchRegionName,
            kind: media.kind
        )

        MediaCreditsView(creators: detail.creators, cast: detail.credits)

        if !detail.genres.isEmpty {
            MediaDetailSection(title: "Genres") {
                FlowLayout {
                    ForEach(detail.genres, id: \.self) { genre in
                        MediaDetailChip(text: genre)
                    }
                }
            }
        }

        if let sourceURL = detail.sourceURL {
            Link(destination: sourceURL) {
                Text("More on \(sourceLabel) ↗")
                    .font(Theme.Font.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
            }
        }
    }

    /// Nil hides the "Log this" button entirely — for a hand-typed row
    /// there's nothing to hand the composer.
    private var logAction: (() -> Void)? {
        guard viewModel?.logCandidate != nil else { return nil }
        return presentComposer
    }

    private var loadedDetail: MediaDetail? {
        if case let .loaded(detail) = viewModel?.state {
            return detail
        }
        return nil
    }

    private var sourceLabel: String {
        switch media.externalSource {
        case .tmdb: "TMDB"
        case .openlibrary: "OpenLibrary"
        case .musicbrainz: "MusicBrainz"
        case nil: "the source"
        }
    }

    // MARK: - Composer

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

    /// "Log this" skips search entirely: we already know exactly which item
    /// the user means, so the composer opens straight on the rating step.
    private func presentComposer() {
        guard let candidate = viewModel?.logCandidate else { return }

        let composer = composerViewModel ?? ComposerViewModel(
            service: ComposerService(
                tmdb: config.tmdbAPIKey.map { TMDBService(apiKey: $0) },
                client: clientProvider.client
            )
        )
        composerViewModel = composer
        composer.pick(candidate)
    }

    private func ensureLoaded() async {
        if viewModel == nil {
            let model = MediaDetailViewModel(
                media: media,
                service: MediaDetailService(tmdbAPIKey: config.tmdbAPIKey)
            )
            viewModel = model
            await model.load()
        }
    }
}

#Preview {
    NavigationStack {
        MediaDetailView(
            media: Media(
                id: UUID(),
                kind: .movie,
                title: "Past Lives",
                year: 2023,
                primaryCreator: "Celine Song",
                coverURL: nil,
                externalID: "666277",
                externalSource: .tmdb,
                createdAt: .now
            )
        )
    }
    .environment(AppConfig.preview)
    .environment(SupabaseClientProvider.preview)
}
