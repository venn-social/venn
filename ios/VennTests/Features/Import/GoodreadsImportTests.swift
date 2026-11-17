import Foundation
import Testing
@testable import Venn

/// The same sample export as web's `goodreads.test.ts`, so both platforms
/// are held to identical results.
struct GoodreadsImportTests {
    private static let header = [
        "Book Id,Title,Author,Author l-f,Additional Authors,ISBN,ISBN13,My Rating,Average Rating,Publisher,",
        "Binding,Number of Pages,Year Published,Original Publication Year,Date Read,Date Added,Bookshelves,",
        "Bookshelves with positions,Exclusive Shelf,My Review,Spoiler,Private Notes,Read Count,Owned Copies",
    ].joined()

    /// One export line. Columns venn does not read are left empty.
    private static func line(
        _ id: String,
        _ title: String,
        _ author: String,
        isbn13: String = "",
        rating: Int = 0,
        published: String = "",
        original: String = "",
        read: String = "",
        added: String = "",
        shelf: String = "read"
    ) -> String {
        let quoted = title.contains(",") ? "\"\(title)\"" : title
        return [
            id, quoted, author, "", "", #"="""#, #"="\#(isbn13)""#, String(rating), "", "", "", "",
            published, original, read, added, "", "", shelf, "", "", "", "", "",
        ].joined(separator: ",")
    }

    private static let rows = [
        line(
            "2767052",
            "The Hunger Games (The Hunger Games, #1)",
            "Suzanne Collins",
            isbn13: "9780439023481",
            rating: 5,
            published: "2008",
            original: "2008",
            read: "2023/01/15",
            added: "2022/12/01"
        ),
        line("1", "Middlemarch", "George Eliot", rating: 4, published: "2003", original: "1871", added: "2021/05/02"),
        line("2", "Stoner", "John Williams", isbn13: "9781590171998", rating: 3, read: "2020/03/03"),
        line("3", "Ulysses", "James Joyce", original: "1922", added: "2019/01/01"),
        line("4", "Piranesi", "Susanna Clarke", added: "2024/02/02", shelf: "to-read"),
        line("5", "The Overstory", "Richard Powers", added: "2024/03/03", shelf: "currently-reading"),
        line("6", "Infinite Jest", "David Foster Wallace", added: "2018/01/01", shelf: "did-not-finish"),
        line("7", "Bad Book", "Some One", rating: 1, read: "2015/06/06"),
    ]

    private let parsed = GoodreadsImport.parse(([Self.header] + Self.rows).joined(separator: "\n"))

    private func entry(_ title: String) -> ImportEntry? {
        parsed.entries.first { $0.title == title }
    }

    @Test
    func importsSupportedShelvesAndReportsCustomOnes() {
        #expect(parsed.entries.count == 7)
        #expect(parsed.problems == [
            ImportRowProblem(file: GoodreadsImport.fileName, line: 8, reason: .unsupportedShelf),
        ])
    }

    @Test
    func ratesReadBooksOnTheSharedScale() {
        let hungerGames = entry("The Hunger Games (The Hunger Games, #1)")
        #expect(hungerGames?.action == .rated)
        #expect(hungerGames?.rating == 5)
        #expect(hungerGames?.creator == "Suzanne Collins")
        #expect(hungerGames?.isbn == "9780439023481")
        #expect(hungerGames?.year == 2008)
        #expect(hungerGames?.consumedAt == "2023-01-15")
        #expect(entry("Middlemarch")?.rating == 3)
        #expect(entry("Middlemarch")?.year == 1871)
        #expect(entry("Stoner")?.action == .logged)
        #expect(entry("Bad Book")?.rating == 1)
    }

    @Test
    func unratedReadBooksAreLoggedAndDatedByDateAdded() {
        #expect(entry("Ulysses")?.action == .logged)
        #expect(entry("Ulysses")?.rating == nil)
        #expect(entry("Ulysses")?.consumedAt == "2019-01-01")
    }

    @Test
    func toReadAndCurrentlyReadingAreSaved() {
        #expect(entry("Piranesi")?.action == .saved)
        #expect(entry("Piranesi")?.consumedAt == "2024-02-02")
        #expect(entry("The Overstory")?.action == .saved)
    }

    @Test
    func everyEntryIsABook() {
        #expect(parsed.entries.allSatisfy { $0.kind == .book })
    }

    @Test
    func skipsARepeatedBookIdAndReportsAMissingTitle() {
        let text = [Self.header, Self.rows[0], Self.rows[0], "9,,Nobody,,,,,0,,,,,,,,,,,read"].joined(separator: "\n")
        let result = GoodreadsImport.parse(text)
        #expect(result.entries.count == 1)
        #expect(result.problems == [ImportRowProblem(file: GoodreadsImport.fileName, line: 4, reason: .missingTitle)])
    }

    @Test
    func unwrapsSpreadsheetFormulaISBNs() {
        #expect(GoodreadsImport.parseISBN(#"="9780439023481""#) == "9780439023481")
        #expect(GoodreadsImport.parseISBN(#"="043902348X""#) == "043902348X")
        #expect(GoodreadsImport.parseISBN(#"="""#) == nil)
        #expect(GoodreadsImport.parseISBN("12345") == nil)
        #expect(GoodreadsImport.parseISBN(nil) == nil)
    }

    @Test
    func convertsSlashedDates() {
        #expect(GoodreadsImport.parseDate("2023/01/15") == "2023-01-15")
        #expect(GoodreadsImport.parseDate("15/01/2023") == nil)
        #expect(GoodreadsImport.parseDate("") == nil)
    }
}
