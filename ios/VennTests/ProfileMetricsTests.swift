import Foundation
import Testing
@testable import Venn

struct ProfileMetricsTests {
    @Test
    func emptyRowsProduceEmptyMetrics() {
        let metrics = ProfileMetrics(rows: [])
        #expect(metrics == .empty)
    }

    @Test
    func aggregatesTotalsAndPerCategory() {
        let metrics = ProfileMetrics(rows: [
            row(.logged, .movie),
            row(.rated, .movie), // logged + rated for movies
            row(.saved, .movie),
            row(.logged, .book),
            row(.saved, .book),
            row(.saved, .book), // 2 saves
            row(.rated, .album),
        ])

        #expect(metrics.totalLogged == 4) // logged or rated: 2 movies + 1 book + 1 album
        #expect(metrics.totalSaved == 3) // 1 movie + 2 books
        #expect(metrics.totalRated == 2) // 1 movie + 1 album

        #expect(metrics.perCategory[.movie] == PerCategoryMetrics(watched: 2, watchlist: 1))
        #expect(metrics.perCategory[.book] == PerCategoryMetrics(watched: 1, watchlist: 2))
        #expect(metrics.perCategory[.album] == PerCategoryMetrics(watched: 1, watchlist: 0))
        #expect(metrics.perCategory[.show] == nil)
    }

    @Test
    func unknownActionOrKindIsSkipped() {
        // Forwards-compat: server adds a new action / kind before the
        // client knows about it. Skip, don't crash, don't double-count.
        let metrics = ProfileMetrics(rows: [
            row(.logged, .movie),
            ProfileMetricsRow(action: "reposted", media: .init(kind: "movie")), // unknown action
            ProfileMetricsRow(action: "logged", media: .init(kind: "podcast")), // unknown kind
        ])

        #expect(metrics.totalLogged == 1)
        #expect(metrics.perCategory.count == 1)
    }

    private func row(_ action: PostAction, _ kind: MediaKind) -> ProfileMetricsRow {
        ProfileMetricsRow(
            action: action.rawValue,
            media: .init(kind: kind.rawValue)
        )
    }
}
