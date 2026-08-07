import Foundation
import Testing
@testable import Venn

/// The same cases as web's `recommendations.test.ts`. This function is the
/// only logic that exists on both platforms; if these two suites ever
/// disagree, the platforms have drifted.
struct RecommendationAssemblerTests {
    private static func candidate(
        _ externalID: String,
        kind: MediaKind = .movie
    ) -> MediaCandidate {
        MediaCandidate(
            title: "Title \(externalID)",
            primaryCreator: nil,
            year: nil,
            coverURL: nil,
            overview: nil,
            externalID: externalID,
            externalSource: .tmdb,
            kind: kind
        )
    }

    /// A hand-typed row: no external identity, so nothing to dedup on.
    private static func media(_ index: Int) -> Media {
        Media(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID(),
            kind: .movie,
            title: "Media \(index)",
            year: nil,
            primaryCreator: nil,
            coverURL: nil,
            externalID: nil,
            externalSource: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private static func shelf(
        _ source: ShelfSource,
        seedTitle: String? = nil,
        _ ids: [String]
    ) -> CandidateShelf {
        CandidateShelf(
            source: source,
            seedTitle: seedTitle,
            candidates: ids.map { candidate($0) }
        )
    }

    @Test
    func returnsNothingWhenThereIsNothing() {
        #expect(RecommendationAssembler.assembleShelves(
            feed: .empty, candidateShelves: []
        ).isEmpty)
    }

    @Test
    func dropsAShelfWithFewerThanThreeItems() {
        // Two covers under a heading reads as broken, not as a recommendation.
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [Self.shelf(.trending, ["1", "2"])]
        )

        #expect(shelves.isEmpty)
    }

    @Test
    func keepsAShelfWithExactlyThree() {
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [Self.shelf(.trending, ["1", "2", "3"])]
        )

        #expect(shelves.count == 1)
        #expect(shelves[0].items.count == 3)
    }

    @Test
    func neverShowsSomethingTheViewerHasAlreadySeen() {
        let feed = RecommendationFeed(
            sections: [],
            seeds: [],
            excluded: [ExcludedKey(source: .tmdb, kind: .movie, id: "2")]
        )
        let shelves = RecommendationAssembler.assembleShelves(
            feed: feed,
            candidateShelves: [Self.shelf(.trending, ["1", "2", "3", "4"])]
        )

        #expect(shelves[0].items.count == 3)
        let ids = shelves[0].items.map(\.id)
        #expect(!ids.contains("tmdb:movie:2"))
    }

    @Test
    func excludesOnKindAsWellAsID() {
        // TMDB movie 5 and show 5 are different things; excluding the movie
        // must not hide the show.
        let feed = RecommendationFeed(
            sections: [],
            seeds: [],
            excluded: [ExcludedKey(source: .tmdb, kind: .movie, id: "5")]
        )
        let shelves = RecommendationAssembler.assembleShelves(
            feed: feed,
            candidateShelves: [
                CandidateShelf(
                    source: .trending,
                    seedTitle: nil,
                    candidates: [
                        Self.candidate("5", kind: .show),
                        Self.candidate("6"),
                        Self.candidate("7"),
                    ]
                ),
            ]
        )

        #expect(shelves[0].items.count == 3)
    }

    @Test
    func showsAnItemOnceInTheHighestTierThatHasIt() {
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [
                Self.shelf(.similar, seedTitle: "Past Lives", ["1", "2", "3"]),
                Self.shelf(.trending, ["1", "4", "5", "6"]),
            ]
        )

        #expect(shelves[0].items.count == 3)
        // "1" was taken by the similar shelf, so trending is down to three.
        #expect(shelves[1].items.count == 3)
    }

    @Test
    func ordersShelvesByTierNotByArrival() {
        let feed = RecommendationFeed(
            sections: [
                FeedSection(source: .followed, items: [Self.media(1), Self.media(2), Self.media(3)]),
                FeedSection(
                    source: .tasteTwins,
                    items: [Self.media(4), Self.media(5), Self.media(6)]
                ),
            ],
            seeds: [],
            excluded: []
        )
        let shelves = RecommendationAssembler.assembleShelves(
            feed: feed,
            candidateShelves: [Self.shelf(.trending, ["1", "2", "3"])]
        )

        #expect(shelves.map(\.source) == [.tasteTwins, .followed, .trending])
    }

    @Test
    func keepsAtMostFourShelves() {
        let many = (1...5).map { seed in
            Self.shelf(.similar, seedTitle: "Seed \(seed)", ["\(seed)a", "\(seed)b", "\(seed)c"])
        }

        #expect(RecommendationAssembler.assembleShelves(
            feed: .empty, candidateShelves: many
        ).count == 4)
    }

    @Test
    func capsAShelfAtTwelveItems() {
        let ids = (0..<30).map { "c\($0)" }
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [Self.shelf(.trending, ids)]
        )

        #expect(shelves[0].items.count == 12)
    }

    @Test
    func carriesTheSeedTitleSoTheShelfCanNameWhatItIsLike() {
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [Self.shelf(.similar, seedTitle: "Past Lives", ["1", "2", "3"])]
        )

        #expect(shelves[0].title == "More like Past Lives")
    }

    @Test
    func keepsAHandTypedRowWhichHasNoCatalogIdentityToDedupOn() {
        // These come from venn's own data, so there is nothing to exclude
        // them against — dropping them would silently thin the shelf.
        let feed = RecommendationFeed(
            sections: [
                FeedSection(
                    source: .followed,
                    items: [Self.media(1), Self.media(2), Self.media(3)]
                ),
            ],
            seeds: [],
            excluded: []
        )

        #expect(RecommendationAssembler.assembleShelves(
            feed: feed, candidateShelves: []
        )[0].items.count == 3)
    }
}
