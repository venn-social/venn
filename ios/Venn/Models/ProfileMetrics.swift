import Foundation

/// Aggregate stats for a user's profile — the three top-level tiles
/// (logged / saved / rated) plus per-category breakdowns for the
/// library section.
///
/// **Definitions.** "Logged" totals *all* consumption events
/// (`action == .logged || action == .rated`) because both represent
/// "I consumed this." "Rated" is the subset with a rating — it
/// intentionally overlaps with logged, since the two tiles answer
/// different questions ("how much have I watched" vs "how much have
/// I formed opinions on"). "Saved" is watchlist intent
/// (`action == .saved`).
///
/// Overlap with another user isn't here — that's a viewing-someone-
/// else-profile concept and lands when profile-by-username navigation
/// does. Self-view has no overlap counterpart.
struct ProfileMetrics: Equatable {
    let totalLogged: Int
    let totalSaved: Int
    let totalRated: Int
    let perCategory: [MediaKind: PerCategoryMetrics]

    static let empty = ProfileMetrics(
        totalLogged: 0,
        totalSaved: 0,
        totalRated: 0,
        perCategory: [:]
    )
}

/// Library-section counts for a single media kind.
struct PerCategoryMetrics: Equatable {
    /// All consumption events for this kind (logged + rated).
    let watched: Int
    /// Saved-for-later for this kind.
    let watchlist: Int

    static let zero = PerCategoryMetrics(watched: 0, watchlist: 0)
}

extension ProfileMetrics {
    /// Fold the raw `(action, kind)` rows from
    /// `ProfileService.metrics(for:)` into the aggregate.
    /// Forwards-compat: rows with unknown `action` or `kind` raw values
    /// are skipped (same pattern as `Media.init?(row:)`).
    init(rows: [ProfileMetricsRow]) {
        var logged = 0
        var saved = 0
        var rated = 0
        var perCat: [MediaKind: PerCategoryMetrics] = [:]

        for row in rows {
            guard let action = PostAction(rawValue: row.action),
                  let kind = MediaKind(rawValue: row.media.kind)
            else { continue }

            let existing = perCat[kind] ?? .zero
            switch action {
            case .logged, .rated:
                logged += 1
                perCat[kind] = PerCategoryMetrics(
                    watched: existing.watched + 1,
                    watchlist: existing.watchlist
                )
                if action == .rated { rated += 1 }
            case .saved:
                saved += 1
                perCat[kind] = PerCategoryMetrics(
                    watched: existing.watched,
                    watchlist: existing.watchlist + 1
                )
            }
        }

        totalLogged = logged
        totalSaved = saved
        totalRated = rated
        perCategory = perCat
    }
}

/// Wire-format row for the `ProfileService.metrics(for:)` query. Just
/// the action + the joined media's kind — we don't need the full media
/// or post row for aggregation.
struct ProfileMetricsRow: Decodable, Equatable {
    let action: String
    let media: KindOnly

    struct KindOnly: Decodable, Equatable {
        let kind: String
    }
}
