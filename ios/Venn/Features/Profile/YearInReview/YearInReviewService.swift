import Foundation
import Supabase

/// Per-kind personal stats, as returned by the `personal_stats_by_kind`
/// RPC. Always the caller's own stats — the RPC takes no target-user
/// parameter, unlike `OverlapService`, which compares two people.
struct KindStats: Decodable, Equatable {
    let kind: MediaKind
    let consumedCount: Int
    let savedCount: Int
    let ratedCount: Int
    let avgRating: Double?
    let topCreator: String?
    let topCreatorCount: Int?

    enum CodingKeys: String, CodingKey {
        case kind
        case consumedCount = "consumed_count"
        case savedCount = "saved_count"
        case ratedCount = "rated_count"
        case avgRating = "avg_rating"
        case topCreator = "top_creator"
        case topCreatorCount = "top_creator_count"
    }
}

/// One trailing-12-month bucket, as returned by `personal_stats_monthly`.
/// Zero-filled server-side, so there are always exactly 12 points to plot.
struct MonthlyStat: Decodable, Equatable {
    let month: Date
    let count: Int

    enum CodingKeys: String, CodingKey {
        case month
        case count
    }

    init(month: Date, count: Int) {
        self.month = month
        self.count = count
    }

    /// `month` comes back as a bare `date` (`"2026-07-01"`), not a
    /// timestamp — decode it with a dedicated day formatter rather than
    /// relying on whatever `Date` strategy the shared decoder uses for
    /// timestamped columns elsewhere.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode(String.self, forKey: .month)
        guard let month = Self.dayFormatter.date(from: raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .month,
                in: container,
                debugDescription: "Expected yyyy-MM-dd, got \(raw)"
            )
        }
        self.month = month
        count = try container.decode(Int.self, forKey: .count)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter
    }()
}

/// Everything the Year in Review screen renders: per-kind breakdowns plus
/// the trailing-12-month activity chart. Pure aggregation over what the
/// service fetches — no Supabase types leak past this file.
struct YearInReviewSummary: Equatable {
    let kinds: [KindStats]
    let monthly: [MonthlyStat]

    var totalConsumed: Int {
        kinds.reduce(0) { $0 + $1.consumedCount }
    }
}

/// Fetches personal stats via the `personal_stats_by_kind` and
/// `personal_stats_monthly` RPCs. Both already scope to `auth.uid()`
/// server-side, so — unlike the rest of `Features/Profile` — there's no
/// `userID` parameter: this screen only ever shows your own stats.
protocol YearInReviewServicing: Sendable {
    func summary() async throws -> YearInReviewSummary
}

struct YearInReviewService: YearInReviewServicing {
    let client: SupabaseClient

    func summary() async throws -> YearInReviewSummary {
        do {
            async let kinds: [KindStats] = client
                .rpc("personal_stats_by_kind")
                .execute()
                .value
            async let monthly: [MonthlyStat] = client
                .rpc("personal_stats_monthly")
                .execute()
                .value
            return try await YearInReviewSummary(kinds: kinds, monthly: monthly)
        } catch {
            throw AppError.from(error)
        }
    }
}
