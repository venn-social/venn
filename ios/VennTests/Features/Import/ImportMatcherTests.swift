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

    // MARK: - Books

    private func book(_ id: String, _ title: String, _ author: String?) -> MediaCandidate {
        MediaCandidate(
            title: title,
            primaryCreator: author,
            year: nil,
            coverURL: nil,
            overview: nil,
            externalID: id,
            externalSource: .openlibrary,
            kind: .book
        )
    }

    @Test
    func bookTitleKeyDropsSeriesAndSubtitle() {
        #expect(ImportMatcher.bookTitleKey("Catching Fire (The Hunger Games, #2)") == "catching fire")
        #expect(ImportMatcher.bookTitleKey("Sapiens: A Brief History of Humankind") == "sapiens")
        #expect(ImportMatcher.bookTitleKey("The Way of Kings (The Stormlight Archive, #1.5)") == "way of kings")
        #expect(ImportMatcher.bookTitleKey("Love (in theory)") == "love in theory")
    }

    @Test
    func bookMatchRequiresTheAuthorsSurnameWhenBothHaveOne() {
        let results = [
            book("W1", "Middlemarch", "Someone Else"),
            book("W2", "Middlemarch: A Study of Provincial Life", "George Eliot"),
        ]
        #expect(ImportMatcher.bestBookMatch(title: "Middlemarch", author: "George Eliot", candidates: results)?
            .externalID == "W2")
        #expect(ImportMatcher.bestBookMatch(title: "Middlemarch", author: nil, candidates: results)?.externalID == "W1")
        #expect(ImportMatcher
            .bestBookMatch(title: "Daniel Deronda", author: "George Eliot", candidates: results) == nil)
    }
}
