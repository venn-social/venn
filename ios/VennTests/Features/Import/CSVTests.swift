import Foundation
import Testing
@testable import Venn

/// Mirrors web's `lib/import/__tests__/csv.test.ts`.
struct CSVTests {
    @Test
    func splitsPlainRowsAndFields() {
        #expect(CSV.parse("a,b\n1,2\n") == [["a", "b"], ["1", "2"]])
    }

    @Test
    func keepsCommasDoubledQuotesAndNewlinesInsideQuotedFields() {
        let text = "Name,Review\n\"Crouching Tiger, Hidden Dragon\",\"He said \"\"wow\"\"\nthen left\"\n"
        #expect(CSV.parse(text) == [
            ["Name", "Review"],
            ["Crouching Tiger, Hidden Dragon", "He said \"wow\"\nthen left"],
        ])
    }

    @Test
    func handlesCRLFByteOrderMarkAndMissingFinalNewline() {
        #expect(CSV.parse("\u{FEFF}a,b\r\n1,2") == [["a", "b"], ["1", "2"]])
    }

    @Test
    func keepsEmptyFieldsAndDropsBlankLines() {
        #expect(CSV.parse("a,,c\n\n1,,\n") == [["a", "", "c"], ["1", "", ""]])
    }

    @Test
    func recordsAreKeyedByTrimmedHeaderNames() {
        #expect(CSV.records(" Name ,Year\nHeat,1995\n") == [["Name": "Heat", "Year": "1995"]])
    }

    @Test
    func shortRowsLackTheMissingKeys() {
        #expect(CSV.records("Name,Year,Rating\nHeat\n") == [["Name": "Heat"]])
    }

    @Test
    func emptyFileHasNoRecords() {
        #expect(CSV.records("").isEmpty)
    }
}
