import Foundation
import Supabase

/// Per-kind slice of the taste overlap between the viewer and another
/// user, as returned by the `compute_overlap` RPC. Counts are distinct
/// consumed items (logged/rated — watchlist saves are intent, not taste).
struct KindOverlap: Decodable, Equatable {
    let kind: MediaKind
    let viewerCount: Int
    let otherCount: Int
    let sharedCount: Int

    enum CodingKeys: String, CodingKey {
        case kind
        case viewerCount = "viewer_count"
        case otherCount = "other_count"
        case sharedCount = "shared_count"
    }
}

/// Everything the overlap section renders: the per-kind slices plus the
/// totals the Venn diagram needs. Pure aggregation — covered by unit tests.
struct OverlapSummary: Equatable {
    let kinds: [KindOverlap]
    let viewerTotal: Int
    let otherTotal: Int
    let sharedTotal: Int

    init(kinds: [KindOverlap]) {
        self.kinds = kinds
        viewerTotal = kinds.reduce(0) { $0 + $1.viewerCount }
        otherTotal = kinds.reduce(0) { $0 + $1.otherCount }
        sharedTotal = kinds.reduce(0) { $0 + $1.sharedCount }
    }

    /// Taste match (Jaccard) across all kinds as a whole-number percent.
    /// `nil` when neither person has logged anything to compare.
    var matchPercent: Int? {
        TasteMatch.percent(shared: sharedTotal, viewer: viewerTotal, other: otherTotal)
    }
}

/// Fetches the taste overlap via the `compute_overlap` RPC. The server
/// does the math (and the rate limiting, per CLAUDE.md rule 8) — the
/// client never pulls another user's full library to diff locally.
protocol OverlapServicing: Sendable {
    func overlap(with otherUserID: UUID) async throws -> OverlapSummary
}

struct OverlapService: OverlapServicing {
    let client: SupabaseClient

    func overlap(with otherUserID: UUID) async throws -> OverlapSummary {
        do {
            let kinds: [KindOverlap] = try await client
                .rpc("compute_overlap", params: ["other_user": otherUserID])
                .execute()
                .value
            return OverlapSummary(kinds: kinds)
        } catch {
            throw AppError.from(error)
        }
    }
}
