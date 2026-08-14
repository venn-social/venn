import Foundation

/// Choosing which form of an author's name to show.
///
/// Open Library stores a Japanese author as 村上春樹 and a Russian one in
/// Cyrillic, because that is the name on the book. The app is in English,
/// so a shelf reading "2001 · 村上春樹" is a name most of its readers cannot
/// read, search for, or say out loud.
///
/// The author record carries a Latin form in `personal_name`, written
/// surname-first — "Murakami, Haruki". That is authoritative, unlike the
/// nineteen entries in `alternate_names`, which mix transliterations,
/// ALL-CAPS variants, other scripts, and in one case a research society.
/// Guessing from that list is how you end up showing "Kharuki Murakami".
enum AuthorName {
    /// True when every letter is Latin, so diacritics survive.
    ///
    /// Süskind and Céline must pass — the point is script, not ASCII.
    /// Latin Unicode runs to Latin Extended-B and IPA at U+02AF; anything
    /// beyond is Greek, Cyrillic, Hebrew, Arabic, CJK and the rest.
    static func isLatinScript(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { scalar in
            !scalar.properties.isAlphabetic || scalar.value <= 0x02AF
        }
    }

    /// "Murakami, Haruki" → "Haruki Murakami".
    ///
    /// Only the single-comma case is flipped. "Smith, John, Jr." and other
    /// shapes are left alone rather than reordered into something wrong.
    static func flippingSurnameFirst(_ value: String) -> String {
        let parts = value.components(separatedBy: ",")
        guard parts.count == 2 else { return value.trimmingCharacters(in: .whitespaces) }

        let surname = parts[0].trimmingCharacters(in: .whitespaces)
        let given = parts[1].trimmingCharacters(in: .whitespaces)
        guard !surname.isEmpty, !given.isEmpty else {
            return value.trimmingCharacters(in: .whitespaces)
        }
        return "\(given) \(surname)"
    }

    /// The name to display, preferring the reader's script.
    ///
    /// Keeps `name` whenever it is already Latin — most authors are, and
    /// their `personal_name` is often a worse, surname-first duplicate.
    /// Falls back to `name` when there is no Latin alternative, because a
    /// name in the wrong script beats no name at all.
    static func preferred(name: String?, personalName: String?) -> String? {
        // An empty string is an absent name, not a name that happens to be
        // blank. Web treats it the same way; without this the two platforms
        // disagree on a record with neither field.
        let personal = (personalName?.isEmpty == false) ? personalName : nil

        guard let name, !name.isEmpty else {
            return personal.map(flippingSurnameFirst)
        }
        guard !isLatinScript(name) else { return name }

        guard let personalName = personal else { return name }
        let flipped = flippingSurnameFirst(personalName)
        return isLatinScript(flipped) ? flipped : name
    }
}
