import SwiftUI

/// The recommendation shelves in Explorer.
///
/// With `kind` set, the shelves are narrowed to that media kind — what the
/// per-kind tabs show. They used to show the newest rows in the catalog
/// instead, which is a list of what other people happened to log rather
/// than a recommendation, and the profile page's job.
///
/// In the All tab (`kind` nil) an empty result renders nothing at all: the
/// search prompt below is already a reasonable thing to look at. In a
/// per-kind tab it says so, because there is nothing else on the screen.
struct RecommendationsView: View {
    let viewModel: RecommendationsViewModel
    /// Narrow to one media kind. Nil shows every shelf, for the All tab.
    var kind: MediaKind?
    let onSelectCandidate: (MediaCandidate) -> Void

    var body: some View {
        switch viewModel.state {
        case .loading:
            DeferredLoadingView(caption: "Finding things for you…")
        case let .loaded(all):
            let shelves = kind.map { RecommendationAssembler.shelves(all, for: $0) } ?? all
            if !shelves.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ForEach(shelves) { shelf in
                        RecommendationShelfView(shelf: shelf, onSelectCandidate: onSelectCandidate)
                    }
                }
            } else if kind != nil {
                EmptyStateView(
                    systemImage: "sparkles",
                    title: "No recommendations yet",
                    message: "Log a few things you liked and they'll show up here."
                )
            }
        case let .error(reason):
            ErrorStateView(reason: reason, unknownTitle: "Couldn't load recommendations") {
                Task { await viewModel.load() }
            }
        }
    }
}
