import Foundation

/// Turns a Letterboxd export into one entry per film. Mirrors web's
/// `lib/import/letterboxd.ts`.
///
/// A film can appear in several files — watched, a few diary entries, a
/// rating, even the watchlist — and venn keeps one row per film, so the
/// files are merged:
/// - Watched anywhere (watched, diary or ratings) → logged, rated if a
///   rating exists. Watched beats watchlist.
/// - Only on the watchlist → saved.
/// - The rating is ratings.csv's (the current one), falling back to the
///   newest rated diary entry.
/// - The date is the newest watched date, or the date it was added to the
///   watchlist.
///
/// Films are keyed by normalized title + year rather than the "Letterboxd
/// URI" column, because diary.csv's URI points at the diary entry, not the
/// film, so the same film has different URIs in different files.
enum LetterboxdImport {
    /// The export files this importer reads, in the order they are merged.
    enum File: String, CaseIterable {
        case watched = "watched.csv"
        case diary = "diary.csv"
        case ratings = "ratings.csv"
        case watchlist = "watchlist.csv"
    }

    static func parse(_ files: [File: String]) -> ParsedExport {
        var films: [String: FilmState] = [:]
        var order: [String] = []
        var problems: [ImportRowProblem] = []

        for file in File.allCases {
            guard let text = files[file] else { continue }
            for (index, record) in CSV.records(text).enumerated() {
                let line = index + 2
                guard case let .valid(title) = Sanitize.searchQuery(record["Name"] ?? "") else {
                    problems.append(ImportRowProblem(file: file.rawValue, line: line, reason: .titleTooLong))
                    continue
                }
                guard !title.isEmpty else {
                    problems.append(ImportRowProblem(file: file.rawValue, line: line, reason: .missingTitle))
                    continue
                }
                let year = parseYear(record["Year"])
                let key = "\(ImportMatcher.normalizedTitle(title))|\(year.map(String.init) ?? "")"
                if films[key] == nil {
                    films[key] = FilmState(title: title, year: year)
                    order.append(key)
                }
                films[key]?.apply(file: file, record: record)
            }
        }

        let entries = order.compactMap { films[$0]?.entry }
        return ParsedExport(entries: entries, problems: problems)
    }

    /// Letterboxd writes dates as "YYYY-MM-DD"; anything else is ignored.
    static func parseDate(_ cell: String?) -> String? {
        let value = (cell ?? "").trimmingCharacters(in: .whitespaces)
        return value.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) == nil ? nil : value
    }

    static func parseYear(_ cell: String?) -> Int? {
        guard let value = Int((cell ?? "").trimmingCharacters(in: .whitespaces)),
              (1800...2200).contains(value)
        else { return nil }
        return value
    }

    /// The later of two "YYYY-MM-DD" dates; they sort as strings.
    static func newer(_ current: String?, _ candidate: String?) -> String? {
        guard let candidate else { return current }
        guard let current else { return candidate }
        return max(current, candidate)
    }
}

private struct FilmState {
    let title: String
    let year: Int?
    var watched = false
    /// From ratings.csv — the person's current rating, which wins.
    var currentStars: Double?
    /// From the newest rated diary entry, used when ratings.csv has none.
    var diaryStars: Double?
    var diaryStarsDate = ""
    var watchedDate: String?
    var saved = false
    var savedDate: String?

    init(title: String, year: Int?) {
        self.title = title
        self.year = year
    }

    mutating func apply(file: LetterboxdImport.File, record: [String: String]) {
        let date = LetterboxdImport.parseDate(record["Date"])
        switch file {
        case .watched:
            watched = true
            watchedDate = LetterboxdImport.newer(watchedDate, date)
        case .diary:
            watched = true
            let watchedOn = LetterboxdImport.parseDate(record["Watched Date"]) ?? date
            watchedDate = LetterboxdImport.newer(watchedDate, watchedOn)
            let when = watchedOn ?? ""
            if let stars = ImportRating.parseStars(record["Rating"]), when >= diaryStarsDate {
                diaryStars = stars
                diaryStarsDate = when
            }
        case .ratings:
            if let stars = ImportRating.parseStars(record["Rating"]) {
                watched = true
                currentStars = stars
                watchedDate = LetterboxdImport.newer(watchedDate, date)
            }
        case .watchlist:
            saved = true
            savedDate = LetterboxdImport.newer(savedDate, date)
        }
    }

    var entry: ImportEntry {
        if watched {
            let (action, rating) = ImportRating.postValues(stars: currentStars ?? diaryStars)
            return ImportEntry(
                kind: .movie,
                title: title,
                year: year,
                creator: nil,
                isbn: nil,
                action: action,
                rating: rating,
                consumedAt: watchedDate
            )
        }
        return ImportEntry(
            kind: .movie,
            title: title,
            year: year,
            creator: nil,
            isbn: nil,
            action: .saved,
            rating: nil,
            consumedAt: savedDate
        )
    }
}
