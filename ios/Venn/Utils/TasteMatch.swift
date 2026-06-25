import Foundation

/// Taste-match math shared by the overlap summary and the Venn diagram, so
/// the headline percentage and the geometry never drift apart.
///
/// Match is the Jaccard similarity of two logged collections:
/// `|A ∩ B| / |A ∪ B|`, expressed as a whole-number percent.
enum TasteMatch {
    /// Jaccard similarity as a 0–100 integer.
    ///
    /// Returns `nil` when there is nothing to compare (an empty union), so
    /// callers can distinguish "no data yet" from a real 0% match.
    static func percent(shared: Int, viewer: Int, other: Int) -> Int? {
        let union = viewer + other - shared
        guard union > 0 else { return nil }
        let ratio = Double(shared) / Double(union)
        return Int((ratio * 100).rounded())
    }
}
