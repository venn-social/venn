import SwiftUI

/// Personal "Year in Review" — how much you've logged over the trailing
/// twelve months, broken down by kind. Read-only: no actions, nothing to
/// edit, just your own activity reflected back at you. Reached from a
/// button in `ProfileView`'s top bar.
struct YearInReviewView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @Environment(AuthState.self)
    private var authState

    @State private var viewModel: YearInReviewViewModel?

    var body: some View {
        Screen {
            content
        }
        .navigationTitle("Year in Review")
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(for: .navigation) {
            GlassSkyBackground()
        }
        .task { await ensureLoaded() }
    }

    @ViewBuilder private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Adding up your year…")
            case let .loaded(summary):
                loadedView(summary)
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load your stats") {
                    Task { await viewModel.load() }
                }
            }
        } else {
            DeferredLoadingView()
        }
    }

    private func loadedView(_ summary: YearInReviewSummary) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                totalHeader(summary)
                YearInReviewMonthlyChart(monthly: summary.monthly)
                kindCards(summary)
            }
            .padding(.bottom, Theme.Spacing.xxxl)
        }
        .scrollContentBackground(.hidden)
    }

    private func totalHeader(_ summary: YearInReviewSummary) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(verbatim: "\(summary.totalConsumed)")
                .font(Theme.Font.largeTitle)
                .foregroundStyle(Theme.Color.textPrimary)
                .monospacedDigit()
            Text("logged in the last year")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    @ViewBuilder
    private func kindCards(_ summary: YearInReviewSummary) -> some View {
        if summary.kinds.isEmpty {
            EmptyStateView(
                systemImage: "sparkles",
                title: "Nothing logged yet",
                message: "Log a few things and your year in review builds up here."
            )
        } else {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(summary.kinds, id: \.kind) { stats in
                    YearInReviewKindCard(stats: stats)
                }
            }
        }
    }

    private func ensureLoaded() async {
        if viewModel == nil, case .signedIn = authState.status {
            let viewModel = YearInReviewViewModel(
                service: YearInReviewService(client: clientProvider.client)
            )
            self.viewModel = viewModel
            await viewModel.load()
        }
    }
}

#Preview {
    NavigationStack {
        YearInReviewView()
            .environment(SupabaseClientProvider.preview)
            .environment(AuthState(service: AuthService(client: SupabaseClientProvider.preview.client)))
    }
}
