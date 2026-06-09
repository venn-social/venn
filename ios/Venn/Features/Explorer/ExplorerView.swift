import SwiftUI

/// Explorer tab. Loads recent media of the selected kind from
/// `ExplorerService` and renders them as an image-forward grid of covers.
/// Reloads when the user switches the category picker. Header-less and
/// minimal, matching the refreshed Feed. Full-text search needs Postgres
/// `tsvector` infra that hasn't landed yet, so the search field is omitted
/// until it's real.
struct ExplorerView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var selectedCategory: ExplorerCategory = .movies
    @State private var query = ""
    @State private var viewModel: ExplorerViewModel?

    var body: some View {
        NavigationStack {
            Screen {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        SearchField(text: $query, prompt: "Search movies, music, books")
                        categoryPicker
                        catalog
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
        }
        .task { await ensureLoaded() }
        .onChange(of: selectedCategory) { _, newCategory in
            Task { await viewModel?.load(kind: newCategory.mediaKind) }
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

    @ViewBuilder private var catalog: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Looking for something good…")
            case let .loaded(media):
                if media.isEmpty {
                    emptyView
                } else {
                    grid(media)
                }
            case let .error(reason):
                errorView(reason: reason) {
                    Task { await viewModel.load(kind: selectedCategory.mediaKind) }
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

/// One cover in the Explorer grid: an image-forward tile with the title and
/// creator beneath.
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
        .environment(SupabaseClientProvider.preview)
}
