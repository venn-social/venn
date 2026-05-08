import Foundation
import Supabase

/// Profile read surface. Behind a protocol so `ProfileViewModel` can be
/// unit-tested with a hand-rolled fake. Writes (avatar upload, bio edits,
/// etc.) land in a follow-up PR with the editing flow.
protocol ProfileServicing: Sendable {
    /// Fetch the profile row for `userID`. Throws when the row is missing
    /// (i.e. the auth user exists but the trigger that creates the
    /// matching `public.profiles` row hasn't run yet).
    func profile(for userID: UUID) async throws -> UserProfile
}

/// Production implementation backed by the Supabase Postgrest client.
struct ProfileService: ProfileServicing {
    let client: SupabaseClient

    func profile(for userID: UUID) async throws -> UserProfile {
        try await client
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value
    }
}
