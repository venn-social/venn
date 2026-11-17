import Foundation

/// How a star rating from another app becomes a venn sentiment.
///
/// One scale for every import, so a Letterboxd 4.5 and a Goodreads 5 mean
/// the same thing in your library:
///
/// - 4.5–5 stars → Love
/// - 3.5–4 stars → Like
/// - 2.5–3 stars → no sentiment (logged, unrated)
/// - 0.5–2 stars → Dislike
///
/// The middle band is deliberately neutral: "it was fine" is neither a like
/// nor a dislike, and guessing either would put a false opinion on a
/// profile. Mirrors web's `lib/import/rating.ts`.
enum ImportRating {
    static func choice(stars: Double?) -> ComposerViewModel.RatingChoice? {
        guard let stars, stars.isFinite, stars > 0 else { return nil }
        switch stars {
        case 4.5...: return .love
        case 3.5...: return .like
        case 2.5...: return nil
        default: return .dislike
        }
    }

    /// Goes through the composer's own mapping so an imported Love is
    /// stored exactly as a Love logged by hand.
    static func postValues(stars: Double?) -> (action: PostAction, rating: Double?) {
        ComposerViewModel.RatingChoice.postValues(for: choice(stars: stars))
    }

    /// Reads a star rating cell. Empty, zero ("not rated" on Goodreads) and
    /// anything outside 0.5–5 come back as nil rather than as a rating.
    static func parseStars(_ cell: String?) -> Double? {
        guard let cell, let value = Double(cell.trimmingCharacters(in: .whitespaces)) else { return nil }
        guard value.isFinite, value >= 0.5, value <= 5 else { return nil }
        return value
    }
}
