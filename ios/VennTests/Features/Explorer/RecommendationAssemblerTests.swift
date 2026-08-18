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

    // MARK: - Narrowing to one kind

    private static let film = ShelfItem.candidate(candidate("1", kind: .movie))
    private static let book = ShelfItem.candidate(candidate("2", kind: .book))
    private static let row = ShelfItem.media(media(1))

    private static func shelf(_ items: [ShelfItem]) -> RecommendationShelf {
        RecommendationShelf(source: .trending, seedTitle: nil, items: items)
    }

    @Test("keeps only the items of the kind asked for")
    func keepsOnlyTheKindAskedFor() {
        let narrowed = RecommendationAssembler.shelves(
            [Self.shelf([Self.film, Self.book, Self.row])], for: .movie
        )
        #expect(narrowed[0].items.map(\.mediaKind) == [.movie, .movie])
    }

    @Test("reads both sides of the union, not just candidates")
    func readsBothSidesOfTheUnion() {
        let books = RecommendationAssembler.shelves(
            [Self.shelf([Self.film, Self.book, Self.row])], for: .book
        )
        #expect(books[0].items.count == 1)
        #expect(books[0].items[0].mediaKind == .book)
    }

    @Test("drops a shelf that has nothing left rather than showing an empty row")
    func dropsAnEmptiedShelf() {
        #expect(RecommendationAssembler.shelves(
            [Self.shelf([Self.film, Self.row])], for: .album
        ).isEmpty)
    }

    @Test("keeps a shelf of one, unlike assembleShelves")
    func keepsAThinShelf() {
        // Three items is the bar across the whole catalog. Narrowed to one
        // kind the realistic choice is a short shelf or an empty tab, and
        // the empty tab is what this change exists to remove.
        let thin = RecommendationAssembler.shelves(
            [Self.shelf([Self.film, Self.book, Self.row])], for: .book
        )
        #expect(thin[0].items.count == 1)
    }

    @Test("leaves the shelf's identity alone so headings still make sense")
    func keepsShelfIdentity() {
        let named = RecommendationShelf(
            source: .similar, seedTitle: "Her", items: [Self.film, Self.book]
        )
        let narrowed = RecommendationAssembler.shelves([named], for: .movie)
        #expect(narrowed[0].source == .similar)
        #expect(narrowed[0].seedTitle == "Her")
    }
}
