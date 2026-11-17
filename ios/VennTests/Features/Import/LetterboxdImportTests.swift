import Foundation
import Testing
@testable import Venn

/// The same sample export as web's `letterboxd.test.ts`, so both platforms
/// are held to identical results.
struct LetterboxdImportTests {
    private static let watched = """
    Date,Name,Year,Letterboxd URI
    2023-01-02,Heat,1995,https://boxd.it/a
    2023-02-03,Cats,2019,https://boxd.it/b
    2023-03-04,Paddington 2,2017,https://boxd.it/c

    """

    private static let diary = """
    Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date
    2023-01-03,Heat,1995,https://boxd.it/d1,4,,,2023-01-02
    2024-05-01,Heat,1995,https://boxd.it/d2,5,Yes,,2024-04-30
    2023-02-04,Cats,2019,https://boxd.it/d3,,,,2023-02-03

    """

    private static let ratings = """
    Date,Name,Year,Letterboxd URI,Rating
    2023-02-04,Cats,2019,https://boxd.it/b,1
    2023-03-05,Paddington 2,2017,https://boxd.it/c,4.5
    2023-06-01,"Crouching Tiger, Hidden Dragon",2000,https://boxd.it/e,3

    """

    private static let watchlist = """
    Date,Name,Year,Letterboxd URI
    2022-12-01,Heat,1995,https://boxd.it/a
    2022-12-02,Past Lives,2023,https://boxd.it/f

    """

    private let parsed = LetterboxdImport.parse([
        .watched: Self.watched,
        .diary: Self.diary,
        .ratings: Self.ratings,
        .watchlist: Self.watchlist,
    ])

    private func entry(_ title: String) -> ImportEntry? {
        parsed.entries.first { $0.title == title }
    }

    @Test
    func oneEntryPerFilmAcrossAllFiles() {
        #expect(parsed.entries.count == 5)
        #expect(parsed.problems.isEmpty)
    }

    @Test
    func usesTheNewestDiaryRatingWhenRatingsHasNone() {
        let heat = entry("Heat")
        #expect(heat?.action == .rated)
        #expect(heat?.rating == 5)
        #expect(heat?.consumedAt == "2024-04-30")
    }

    @Test
    func prefersTheCurrentRatingInRatingsCSV() {
        #expect(entry("Cats")?.rating == 1)
        #expect(entry("Cats")?.year == 2019)
        #expect(entry("Paddington 2")?.rating == 5)
    }

    @Test
    func logsAMiddlingRatingWithoutASentiment() {
        let film = entry("Crouching Tiger, Hidden Dragon")
        #expect(film?.action == .logged)
        #expect(film?.rating == nil)
        #expect(film?.consumedAt == "2023-06-01")
    }

    @Test
    func savesWatchlistOnlyFilmsAndWatchingWins() {
        let pastLives = entry("Past Lives")
        #expect(pastLives?.action == .saved)
        #expect(pastLives?.consumedAt == "2022-12-02")
        #expect(entry("Heat")?.action == .rated)
    }

    @Test
    func everyEntryIsAMovieWithNoBookFields() {
        for entry in parsed.entries {
            #expect(entry.kind == .movie)
            #expect(entry.creator == nil)
            #expect(entry.isbn == nil)
        }
    }

    @Test
    func reportsRowsWithNoUsableTitle() {
        let long = String(repeating: "x", count: 101)
        let result = LetterboxdImport.parse([
            .watched: "Date,Name,Year\n2023-01-01,,2000\n2023-01-01,\(long),2000\n",
        ])
        #expect(result.entries.isEmpty)
        #expect(result.problems == [
            ImportRowProblem(file: "watched.csv", line: 2, reason: .missingTitle),
            ImportRowProblem(file: "watched.csv", line: 3, reason: .titleTooLong),
        ])
    }

    @Test
    func keepsSameNamedFilmsFromDifferentYearsApart() {
        let result = LetterboxdImport.parse([.watched: "Date,Name,Year\n2023-01-01,Dune,1984\n2023-01-02,Dune,2021\n"])
        #expect(result.entries.compactMap(\.year).sorted() == [1984, 2021])
    }

    @Test
    func emptyExportHasNoEntries() {
        #expect(LetterboxdImport.parse([:]).entries.isEmpty)
    }

    @Test
    func ignoresMalformedDatesAndYears() {
        let result = LetterboxdImport.parse([.watched: "Date,Name,Year\n01/02/2023,Heat,abc\n"])
        #expect(result.entries.first?.year == nil)
        #expect(result.entries.first?.consumedAt == nil)
        #expect(result.entries.first?.action == .logged)
    }
}
