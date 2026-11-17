import Foundation

/// RFC 4180 CSV parsing for the library exports people bring from other apps.
///
/// Hand-rolled rather than a dependency because the format is small and the
/// edge cases that matter are known: quoted fields holding commas, doubled
/// quotes and newlines, CRLF line endings, and a UTF-8 byte-order mark from
/// spreadsheet round-trips. Mirrors web's `lib/import/csv.ts`.
enum CSV {
    /// Every non-blank row, split into fields.
    static func parse(_ text: String) -> [[String]] {
        var parser = Parser()
        // unicodeScalars, not Characters: Swift folds "\r\n" into a single
        // Character, which would hide the line ending from the parser.
        for scalar in text.unicodeScalars {
            parser.consume(scalar)
        }
        return parser.finish().filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
    }

    /// Rows keyed by the trimmed header line. A row shorter than the header
    /// simply lacks the missing keys, so a malformed line degrades to
    /// "missing field" rather than a failure.
    static func records(_ text: String) -> [[String: String]] {
        let rows = parse(text)
        guard let header = rows.first else { return [] }
        let names = header.map { $0.trimmingCharacters(in: .whitespaces) }
        return rows.dropFirst().map { cells in
            var record: [String: String] = [:]
            for (index, name) in names.enumerated() where index < cells.count {
                record[name] = cells[index]
            }
            return record
        }
    }

    private struct Parser {
        private var rows: [[String]] = []
        private var row: [String] = []
        private var field = String.UnicodeScalarView()
        private var inQuotes = false
        /// A quote seen inside a quoted field: either the end of the field or
        /// the first half of an escaped `""`, decided by the next scalar.
        private var pendingQuote = false
        private var afterCarriageReturn = false
        private var atStart = true

        mutating func consume(_ scalar: Unicode.Scalar) {
            if atStart {
                atStart = false
                if scalar == "\u{FEFF}" {
                    return
                }
            }
            if afterCarriageReturn {
                afterCarriageReturn = false
                if scalar == "\n" {
                    return
                }
            }
            if pendingQuote {
                pendingQuote = false
                if scalar == "\"" {
                    field.append(scalar)
                    return
                }
                inQuotes = false
            }
            if inQuotes {
                if scalar == "\"" {
                    pendingQuote = true
                } else {
                    field.append(scalar)
                }
                return
            }
            consumeUnquoted(scalar)
        }

        private mutating func consumeUnquoted(_ scalar: Unicode.Scalar) {
            switch scalar {
            case "\"":
                inQuotes = true
            case ",":
                endField()
            case "\n", "\r":
                afterCarriageReturn = scalar == "\r"
                endField()
                rows.append(row)
                row = []
            default:
                field.append(scalar)
            }
        }

        private mutating func endField() {
            row.append(String(field))
            field = String.UnicodeScalarView()
        }

        mutating func finish() -> [[String]] {
            if !field.isEmpty || !row.isEmpty {
                endField()
                rows.append(row)
                row = []
            }
            return rows
        }
    }
}
