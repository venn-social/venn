import Foundation
import Testing
@testable import Venn

/// Mirrors web's `lib/import/__tests__/match.test.ts`.
struct ImportMatcherTests {
    private func film(_ id: String, _ title: String, _ year: Int?) -> MediaCandidate {
        MediaCandidate(
            title: title,
            primaryCreator: nil,
            year: year,
            coverURL: nil,
            overview: nil,
            externalID: id,
            externalSource: .tmdb,
            kind: .movie
        )
    }

    private var results: [MediaCandidate] {
        [film("1", "Dune", 2021), film("2", "Dune", 1984), film("3", "Dune: Part Two", 2024)]
    }

    @Test
    func normalizationIgnoresCaseAccentsPunctuationAndLeadingArticle() {
        #expect(ImportMatcher.normalizedTitle("The Grand Budapest Hotel") == "grand budapest hotel")
        #expect(ImportMatcher.normalizedTitle("Amélie") == "amelie")
        #expect(ImportMatcher.normalizedTitle("Mission: Impossible – Fallout") == "mission impossible fallout")
    }

    @Test
    func ampersandAndAndAreTheSame() {
        #expect(ImportMatcher.normalizedTitle("Fast & Furious") == ImportMatcher.normalizedTitle("Fast and Furious"))
    }

    @Test
    func prefersSameTitleSameYear() {
        #expect(ImportMatcher.bestMatch(title: "Dune", year: 1984, candidates: results)?.externalID == "2")
    }

    @Test
    func acceptsAYearOffByOne() {
        #expect(ImportMatcher.bestMatch(title: "Dune", year: 1985, candidates: results)?.externalID == "2")
    }

    @Test
    func fallsBackToAContainingTitleInTheSameYear() {
        #expect(ImportMatcher.bestMatch(title: "Dune Part Two", year: 2024, candidates: results)?.externalID == "3")
    }

    @Test
    func takesTheMostRelevantSameTitleWhenThereIsNoYear() {
        #expect(ImportMatcher.bestMatch(title: "dune", year: nil, candidates: results)?.externalID == "1")
    }

    @Test
    func refusesToGuess() {
        #expect(ImportMatcher.bestMatch(title: "Arrival", year: 2016, candidates: results) == nil)
        #expect(ImportMatcher.bestMatch(title: "Dune", year: 1999, candidates: results) == nil)
        #expect(ImportMatcher.bestMatch(title: "", year: 2021, candidates: results) == nil)
    }
}
