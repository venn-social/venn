import Foundation
import Testing
@testable import Venn

/// Tests for the Year in Review wire format, the summary aggregation, and
/// the view-model state machine. The SQL itself runs server-side; the
/// decode tests pin the row shapes `personal_stats_by_kind` and
/// `personal_stats_monthly` return.
struct YearInReviewTests {
    @Test
    func decodesKindStatsRow() throws {
        let json = Data("""
        [{
            "kind": "movie",
            "consumed_count": 34,
            "saved_count": 6,
            "rated_count": 20,
            "avg_rating": 4.2,
            "top_creator": "Denis Villeneuve",
            "top_creator_count": 4
        }]
        """.utf8)

        let rows = try JSONDecoder().decode([KindStats].self, from: json)

        #expect(rows == [
            KindStats(
                kind: .movie,
                consumedCount: 34,
                savedCount: 6,
                ratedCount: 20,
                avgRating: 4.2,
                topCreator: "Denis Villeneuve",
                topCreatorCount: 4
            ),
        ])
    }

    @Test
    func decodesKindStatsRowWithNullCreatorAndRating() throws {
        // A saved-only kind: no logged/rated posts, so the RPC returns null
        // for avg_rating/top_creator/top_creator_count.
        let json = Data("""
        [{
            "kind": "album",
            "consumed_count": 0,
            "saved_count": 3,
            "rated_count": 0,
            "avg_rating": null,
            "top_creator": null,
            "top_creator_count": null
        }]
        """.utf8)

        let rows = try JSONDecoder().decode([KindStats].self, from: json)

        #expect(rows == [
            KindStats(
                kind: .album,
                consumedCount: 0,
                savedCount: 3,
                ratedCount: 0,
                avgRating: nil,
                topCreator: nil,
                topCreatorCount: nil
            ),
        ])
    }

    @Test
    func decodesMonthlyStatRow() throws {
        let json = Data("""
        [{ "month": "2026-07-01", "count": 9 }]
        """.utf8)

        let rows = try JSONDecoder().decode([MonthlyStat].self, from: json)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let expectedMonth = try #require(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1)))

        #expect(rows.count == 1)
        #expect(rows[0].month == expectedMonth)
        #expect(rows[0].count == 9)
    }

    @Test
    func totalConsumedSumsAcrossKinds() {
        let summary = YearInReviewSummary(
            kinds: [
                KindStats(
                    kind: .movie,
                    consumedCount: 34,
                    savedCount: 6,
                    ratedCount: 20,
                    avgRating: 4.2,
                    topCreator: "Denis Villeneuve",
                    topCreatorCount: 4
                ),
                KindStats(
                    kind: .book,
                    consumedCount: 12,
                    savedCount: 1,
                    ratedCount: 5,
                    avgRating: 3.8,
                    topCreator: nil,
                    topCreatorCount: nil
                ),
            ],
            monthly: []
        )

        #expect(summary.totalConsumed == 46)
    }

    @Test
    func totalConsumedOfNothingIsZero() {
        #expect(YearInReviewSummary(kinds: [], monthly: []).totalConsumed == 0)
    }
}

@MainActor
struct YearInReviewViewModelTests {
    @Test
    func loadSuccessTransitionsToLoaded() async {
        let summary = YearInReviewSummary(
            kinds: [
                KindStats(
                    kind: .movie,
                    consumedCount: 10,
                    savedCount: 0,
                    ratedCount: 5,
                    avgRating: 4.0,
                    topCreator: nil,
                    topCreatorCount: nil
                ),
            ],
            monthly: []
        )
        let service = FakeYearInReviewService()
        service.result = .success(summary)
        let viewModel = YearInReviewViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded(summary))
    }

    @Test
    func rateLimitedMapsToRateLimitedReason() async {
        let service = FakeYearInReviewService()
        service.result = .failure(AppError.rateLimited)
        let viewModel = YearInReviewViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.rateLimited))
    }

    @Test
    func networkFailureMapsToOffline() async {
        let service = FakeYearInReviewService()
        service.result = .failure(AppError.network)
        let viewModel = YearInReviewViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func nonAppErrorFallsBackToUnknown() async {
        struct Boom: Error {}
        let service = FakeYearInReviewService()
        service.result = .failure(Boom())
        let viewModel = YearInReviewViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.unknown))
    }
}

// MARK: - Fake

final class FakeYearInReviewService: YearInReviewServicing, @unchecked Sendable {
    var result: Result<YearInReviewSummary, Error> = .success(
        YearInReviewSummary(kinds: [], monthly: [])
    )

    func summary() async throws -> YearInReviewSummary {
        try result.get()
    }
}
