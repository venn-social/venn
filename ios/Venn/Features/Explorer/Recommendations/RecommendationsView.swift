import SwiftUI

/// The recommendation shelves, above Explorer's browse grid.
///
/// Renders nothing when there are no shelves rather than an empty state:
/// the browse grid below is already a reasonable thing to look at, and a
/// "no recommendations yet" message would be noise on top of it.
struct RecommendationsView: View {
    let viewModel: RecommendationsViewModel
    let onSelectCandidate: (MediaCandidate) -> Void

    var body: some View {
        switch viewModel.state {
        case .loading:
            DeferredLoadingView(caption: "Finding things for you…")
        case let .loaded(shelves):
            if !shelves.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ForEach(shelves) { shelf in
                        RecommendationShelfView(shelf: shelf, onSelectCandidate: onSelectCandidate)
                    }
                }
            }
        case let .error(reason):
            // Deliberately quiet: the browse grid below still works, so a
            // full error screen would overstate the damage.
            ErrorStateView(reason: reason, unknownTitle: "Couldn't load recommendations") {
                Task { await viewModel.load() }
            }
        }
    }
}
