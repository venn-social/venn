import Foundation
import Testing
@testable import Venn

/// The rating mapping, now that the composer and the shelf's rating editor
/// both read it from one place. Mirrors web's `ratingToPost` — if these two
/// suites disagree, the same tap writes different rows on each platform.
struct RatingChoiceTests {
    private typealias Choice = ComposerViewModel.RatingChoice

    @Test
    func loveWritesAFiveStarRating() {
        let result = Choice.postValues(for: .love)
        #expect(result.action == .rated)
        #expect(result.rating == 5.0)
    }

    @Test
    func likeWritesThree() {
        let result = Choice.postValues(for: .like)
        #expect(result.action == .rated)
        #expect(result.rating == 3.0)
    }

    @Test
    func dislikeWritesOne() {
        let result = Choice.postValues(for: .dislike)
        #expect(result.action == .rated)
        #expect(result.rating == 1.0)
    }

    @Test
    func skippingLogsWithoutARating() {
        // Skip is not "zero stars" — it is no opinion, which is a different
        // row entirely and must not read as a bad review.
        let result = Choice.postValues(for: nil)
        #expect(result.action == .logged)
        #expect(result.rating == nil)
    }

    @Test
    func everyChoiceRoundTripsThroughItsStoredRating() {
        // The editor opens on whatever you said last time, so this has to
        // invert exactly.
        for choice in Choice.allCases {
            let stored = Choice.postValues(for: choice).rating
            #expect(Choice(rating: stored) == choice)
        }
    }

    @Test
    func anUnratedPostOpensWithNothingSelected() {
        #expect(Choice(rating: nil) == nil)
    }

    @Test
    func ratingsBetweenTheStepsFallToTheNearestChoiceBelow() {
        // Ratings are a 0-5 column, so a value we did not write (an older
        // row, or a future half-step UI) still has to land somewhere sane.
        #expect(Choice(rating: 4.0) == .like)
        #expect(Choice(rating: 2.0) == .dislike)
        #expect(Choice(rating: 0.0) == .dislike)
    }

    @Test
    func everyChoiceHasALabelAndAnIcon() {
        for choice in Choice.allCases {
            #expect(!choice.title.isEmpty)
            #expect(!choice.systemImage.isEmpty)
        }
    }
}
