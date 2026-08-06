import Foundation
import Testing
@testable import Venn

@MainActor
struct RecommendationsViewModelTests {
    @Test
    func aFailedCatalogCallCostsOneShelfNotThePage() async {
        // Providers are independent: one being down must not blank the tab.
        let catalog = FakeCatalogSimilarService()
        catalog.similarError = AppError.network
        catalog.trendingResult = (1...4).map { FakeCatalogSimilarService.candidate("\($0)") }

        let viewModel = RecommendationsViewModel(
            service: FakeRecommendationService(feed: Self.feedWithOneSeed),
            catalog: catalog
        )
        await viewModel.load()

        guard case let .loaded(shelves) = viewModel.state else {
            Issue.record("expected a loaded state")
            return
        }
        #expect(shelves.map(\.source) == [.trending])
    }

    @Test
    func onlyTheRPCFailingIsAnErrorState() async {
        let service = FakeRecommendationService(feed: .empty)
        service.error = AppError.network
        let viewModel = RecommendationsViewModel(
            service: service,
            catalog: FakeCatalogSimilarService()
        )

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func aBrandNewUserGetsNoShelvesRatherThanAnError() async {
        // Empty everything is the normal cold-start payload.
        let viewModel = RecommendationsViewModel(
            service: FakeRecommendationService(feed: .empty),
            catalog: FakeCatalogSimilarService()
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded([]))
    }

    @Test
    func asksTheCatalogForEverySeed() async {
        let catalog = FakeCatalogSimilarService()
        let viewModel = RecommendationsViewModel(
            service: FakeRecommendationService(feed: Self.feedWithOneSeed),
            catalog: catalog
        )

        await viewModel.load()

        #expect(catalog.similarCalls == 1)
        #expect(catalog.trendingCalls == 1)
    }

    private static let feedWithOneSeed = RecommendationFeed(
        sections: [],
        seeds: [
            RecommendationSeed(
                mediaID: UUID(),
                title: "Past Lives",
                kind: .movie,
                externalSource: .tmdb,
                externalID: "666277",
                rating: 5
            ),
        ],
        excluded: []
    )
}

final class FakeRecommendationService: RecommendationServicing, @unchecked Sendable {
    /// Not named `feed`: the protocol requires a `feed()` method, and a
    /// property sharing that base name makes every reference resolve to the
    /// throwing function instead of the value.
    let seeded: RecommendationFeed
    var error: AppError?

    init(feed: RecommendationFeed) {
        seeded = feed
    }

    func feed() async throws -> RecommendationFeed {
        if let error {
            throw error
        }
        return seeded
    }
}

final class FakeCatalogSimilarService: CatalogSimilarServicing, @unchecked Sendable {
    var similarResult: [MediaCandidate] = []
    var trendingResult: [MediaCandidate] = []
    var similarError: AppError?
    var trendingError: AppError?
    private(set) var similarCalls = 0
    private(set) var trendingCalls = 0

    static func candidate(_ externalID: String) -> MediaCandidate {
        MediaCandidate(
            title: "Title \(externalID)",
            primaryCreator: nil,
            year: nil,
            coverURL: nil,
            overview: nil,
            externalID: externalID,
            externalSource: .tmdb,
            kind: .movie
        )
    }

    func similar(to _: RecommendationSeed) async throws -> [MediaCandidate] {
        similarCalls += 1
        if let similarError {
            throw similarError
        }
        return similarResult
    }

    func trending() async throws -> [MediaCandidate] {
        trendingCalls += 1
        if let trendingError {
            throw trendingError
        }
        return trendingResult
    }
}
