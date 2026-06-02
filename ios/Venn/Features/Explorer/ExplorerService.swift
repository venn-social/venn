import Foundation
import Supabase

/// Explorer read surface. Behind a protocol so view-models can be unit-
/// tested with a hand-rolled fake (we don't mock Supabase). Same pattern
/// as `FeedServicing` and `ProfileServicing`.
protocol ExplorerServicing: Sendable {
    /// Recent media of the given kind, newest first, capped at `limit`.
    /// This is what "Recommended for you" surfaces today — a real
    /// recommendation score lands when there's enough signal to compute
    /// one (follow graph + interaction history). The protocol shape
    /// won't change when that happens; the implementation will.
    func recentMedia(kind: MediaKind, limit: Int) async throws -> [Media]
}

/// Production implementation backed by Supabase Postgrest. Funnels
/// third-party errors through `AppError.from(_:)` so callers see a single
/// semantic error type — same pattern as `FeedService` and
/// `ProfileService` (ADR 0006).
struct ExplorerService: ExplorerServicing {
    let client: SupabaseClient

    func recentMedia(kind: MediaKind, limit: Int = 20) async throws -> [Media] {
        do {
            let rows: [MediaSchema.Row] = try await client
                .from("media")
                .select("*")
                .eq("kind", value: kind.rawValue)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return rows.compactMap(Media.init(row:))
        } catch {
            throw AppError.from(error)
        }
    }
}
