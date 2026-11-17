import Foundation

/// Picks which catalog result an export row refers to. Mirrors web's
/// `lib/import/match.ts`.
enum ImportMatcher {
    /// Title comparison key: case, accents, punctuation, "&" vs "and" and a
    /// leading article all differ between catalogs for the same work.
    static func normalizedTitle(_ title: String) -> String {
        let folded = title
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "&", with: " and ")
        let words = folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
        let articles: Set = ["the", "a", "an"]
        if words.count > 1, let first = words.first, articles.contains(first) {
            return words.dropFirst().joined(separator: " ")
        }
        return words.joined(separator: " ")
    }

    /// The safe match for a row, or nil. Results arrive in the catalog's
    /// relevance order, which breaks ties. In order of confidence:
    ///
    /// 1. Same title, same year.
    /// 2. Same title, year off by one — exports and catalogs disagree about
    ///    festival vs. release years.
    /// 3. Same title, and the row has no year to check.
    /// 4. Same year, and one title contains the other ("Dune" vs "Dune: Part
    ///    One") — only when the row has a year to anchor it.
    ///
    /// A row whose title matches nothing is reported unmatched rather than
    /// guessed: a wrong title in someone's library is worse than a gap.
    static func bestMatch(title: String, year: Int?, candidates: [MediaCandidate]) -> MediaCandidate? {
        let key = normalizedTitle(title)
        guard !key.isEmpty else { return nil }
        let sameTitle = candidates.filter { normalizedTitle($0.title) == key }

        guard let year else { return sameTitle.first }
        if let exact = sameTitle.first(where: { $0.year == year }) {
            return exact
        }
        if let near = sameTitle.first(where: { candidate in
            candidate.year.map { abs($0 - year) <= 1 } ?? false
        }) {
            return near
        }
        return candidates.first { candidate in
            guard candidate.year == year else { return false }
            let other = normalizedTitle(candidate.title)
            return !other.isEmpty && (other.contains(key) || key.contains(other))
        }
    }
}
