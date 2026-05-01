import Foundation
import Supabase

/// Thin wrapper over Supabase auth. Screens and view-models call methods on
/// this type rather than touching `SupabaseClient.auth` directly, so the
/// auth surface stays small and testable.
///
/// Add new methods here as auth flows land (sign in with Apple, magic link,
/// password reset, etc.).
struct AuthService {
    let client: SupabaseClient

    func currentSession() async throws -> Session? {
        try? await client.auth.session
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
