import Foundation
import Supabase

/// People lookup for the Explorer "People" category. Matches profiles whose
/// username or display name contains the query (case-insensitive). Behind a
/// protocol so `PeopleSearchViewModel` unit-tests with a fake (ADR 0005).
///
/// Reads are public: the `profiles_select_all` RLS policy allows everyone to
/// read profiles (public-by-default per the product vision), and the trigram
/// indexes from `20260610230000_profile_search.sql` serve the ILIKE match.
protocol PeopleSearchServicing: Sendable {
    /// Profiles matching `query`, ordered by username, capped at `limit`.
    /// An effectively-empty query returns `[]` without a network call.
    func searchProfiles(matching query: String, limit: Int) async throws -> [UserProfile]
}

/// Production implementation backed by Supabase Postgrest. Funnels
/// third-party errors through `AppError.from(_:)` (ADR 0006).
struct PeopleSearchService: PeopleSearchServicing {
    let client: SupabaseClient

    func searchProfiles(matching query: String, limit: Int = 20) async throws -> [UserProfile] {
        let pattern = Self.containsPattern(from: query)
        guard !pattern.isEmpty else { return [] }
        do {
            return try await client
                .from("profiles")
                .select()
                .or("username.ilike.\(pattern),display_name.ilike.\(pattern)")
                .order("username", ascending: true)
                .limit(limit)
                .execute()
                .value
        } catch {
            throw AppError.from(error)
        }
    }

    /// Build a PostgREST contains-pattern (`*term*`) from raw input.
    ///
    /// The raw `.or(...)` filter string is parsed by PostgREST, where commas,
    /// dots, parens, and quotes are syntax and `*` / `%` are multi-character
    /// wildcards — untrusted characters would corrupt the filter or widen the
    /// match, so only letters, digits, spaces, `_`, and `-` survive. `_` is
    /// kept despite being a single-char LIKE wildcard: it's part of the
    /// username alphabet and still matches itself (benign over-match at
    /// worst). Returns "" when nothing searchable remains. Internal so tests
    /// can exercise it directly.
    static func containsPattern(from query: String) -> String {
        let kept = query.unicodeScalars.filter { scalar in
            let properties = scalar.properties
            return properties.isAlphabetic
                || (0x30...0x39).contains(scalar.value) // 0-9
                || scalar == " " || scalar == "_" || scalar == "-"
        }
        let term = String(String.UnicodeScalarView(kept))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return "" }
        return "*\(term)*"
    }
}
