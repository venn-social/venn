import Foundation

/// Turns a Goodreads library export into one entry per book. Mirrors web's
/// `lib/import/goodreads.ts`.
///
/// The "Exclusive Shelf" decides what the book is:
/// - read → logged, rated by "My Rating" (0 means unrated) on the same star
///   scale as every other import, dated "Date Read" (or "Date Added" when
///   Goodreads has no read date).
/// - to-read → saved, dated "Date Added".
/// - currently-reading → saved: not finished, so not logged, but clearly
///   something the person means to get through.
/// - any custom exclusive shelf (e.g. "did-not-finish") → reported, not
///   imported. Logging a book someone abandoned would be a false record.
///
/// Goodreads writes ISBNs as spreadsheet formulas (`="0439023483"`) and
/// dates as "YYYY/MM/DD"; both are normalized here.
enum GoodreadsImport {
    static let fileName = "goodreads_library_export.csv"

    private static let supportedShelves: Set = ["read", "to-read", "currently-reading"]

    static func parse(_ text: String) -> ParsedExport {
        var entries: [ImportEntry] = []
        var problems: [ImportRowProblem] = []
        var seen: Set<String> = []

        for (index, record) in CSV.records(text).enumerated() {
            switch row(record) {
            case let .entry(key, entry):
                // Goodreads exports one row per book, but a hand-merged file may not.
                if seen.insert(key).inserted {
                    entries.append(entry)
                }
            case let .problem(reason):
                problems.append(ImportRowProblem(file: fileName, line: index + 2, reason: reason))
            }
        }
        return ParsedExport(entries: entries, problems: problems)
    }

    private enum Row {
        case entry(key: String, ImportEntry)
        case problem(ImportRowProblem.Reason)
    }

    private static func row(_ record: [String: String]) -> Row {
        guard case let .valid(title) = Sanitize.searchQuery(record["Title"] ?? "") else {
            return .problem(.titleTooLong)
        }
        guard !title.isEmpty else { return .problem(.missingTitle) }

        let shelf = (record["Exclusive Shelf"] ?? "read").trimmingCharacters(in: .whitespaces).lowercased()
        guard supportedShelves.contains(shelf) else { return .problem(.unsupportedShelf) }

        var creator: String?
        if case let .valid(author) = Sanitize.searchQuery(record["Author"] ?? ""), !author.isEmpty {
            creator = author
        }
        let bookID = (record["Book Id"] ?? "").trimmingCharacters(in: .whitespaces)
        let key = bookID.isEmpty ? "\(title)|\(creator ?? "")" : bookID
        let added = parseDate(record["Date Added"])
        let read = shelf == "read"
        var action = PostAction.saved
        var rating: Double?
        if read {
            (action, rating) = ImportRating.postValues(stars: ImportRating.parseStars(record["My Rating"]))
        }

        return .entry(key: key, ImportEntry(
            kind: .book,
            title: title,
            year: LetterboxdImport.parseYear(record["Original Publication Year"])
                ?? LetterboxdImport.parseYear(record["Year Published"]),
            creator: creator,
            isbn: parseISBN(record["ISBN13"]) ?? parseISBN(record["ISBN"]),
            action: action,
            rating: rating,
            consumedAt: read ? parseDate(record["Date Read"]) ?? added : added
        ))
    }

    /// `="9780439023481"`, `9780439023481` or `=""` → the digits, or nil.
    static func parseISBN(_ cell: String?) -> String? {
        let value = (cell ?? "")
            .filter { !"=\" -".contains($0) && !$0.isWhitespace }
            .uppercased()
        return value.wholeMatch(of: /\d{13}|\d{9}[\dX]/) == nil ? nil : value
    }

    /// "2023/01/15" → "2023-01-15"; anything else → nil.
    static func parseDate(_ cell: String?) -> String? {
        let value = (cell ?? "").trimmingCharacters(in: .whitespaces)
        guard let match = value.wholeMatch(of: /(\d{4})\/(\d{2})\/(\d{2})/) else { return nil }
        return "\(match.1)-\(match.2)-\(match.3)"
    }
}
