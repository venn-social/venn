import Foundation
import Testing
@testable import Venn

/// The import star scale. Mirrors web's `lib/import/__tests__/rating.test.ts`
/// — if the two disagree, the same export lands differently per platform.
struct ImportRatingTests {
    typealias Choice = ComposerViewModel.RatingChoice

    @Test(arguments: [
        (5.0, Choice?.some(.love)),
        (4.5, .love),
        (4.0, .like),
        (3.5, .like),
        (3.0, nil),
        (2.5, nil),
        (2.0, .dislike),
        (0.5, .dislike),
    ])
    func mapsStarsToASentiment(stars: Double, expected: Choice?) {
        #expect(ImportRating.choice(stars: stars) == expected)
    }

    @Test
    func noRatingAndZeroHaveNoSentiment() {
        #expect(ImportRating.choice(stars: nil) == nil)
        #expect(ImportRating.choice(stars: 0) == nil)
    }

    @Test(arguments: [
        (5.0, PostAction.rated, Double?.some(5)),
        (4.0, .rated, 3),
        (1.0, .rated, 1),
        (3.0, .logged, nil),
    ])
    func usesTheComposersOwnMapping(stars: Double, action: PostAction, rating: Double?) {
        let result = ImportRating.postValues(stars: stars)
        #expect(result.action == action)
        #expect(result.rating == rating)
    }

    @Test
    func parsesHalfStars() {
        #expect(ImportRating.parseStars("4.5") == 4.5)
        #expect(ImportRating.parseStars(" 3 ") == 3)
    }

    @Test
    func rejectsEmptyZeroOutOfRangeAndJunk() {
        for cell in [nil, "", "0", "6", "five"] {
            #expect(ImportRating.parseStars(cell) == nil)
        }
    }
}
