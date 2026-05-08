import Foundation
import Supabase

/// Auth surface the rest of the app talks to. Behind a protocol so view-models
/// and the AuthState env class can be unit-tested with a fake instead of a
/// real `SupabaseClient`.
///
/// View-models call this protocol; the protocol calls Supabase. Views never
/// touch either directly.
protocol AuthServicing: Sendable {
    /// Stream of session changes. Yields `nil` when the user signs out and a
    /// `Session` when they sign in. The first value is the current session
    /// at the time of subscription.
    var sessionChanges: AsyncStream<Session?> { get }

    /// The current session, or `nil` if signed out. Reads from local storage
    /// without a network round-trip.
    func currentSession() async throws -> Session?

    /// Sends a magic-link email to `email`. The link, when tapped, opens the
    /// app at `redirectTo`; the app then calls `handleCallback(_:)` with the
    /// returned URL to complete sign-in.
    func sendMagicLink(email: String, redirectTo: URL) async throws

    /// Completes sign-in from the URL the magic-link email opened the app
    /// with. Called from `App.onOpenURL`.
    func handleCallback(_ url: URL) async throws

    /// Clears the local session and revokes the refresh token server-side.
    func signOut() async throws
}

/// Production implementation backed by `supabase-swift`'s `GoTrueClient`.
struct AuthService: AuthServicing {
    let client: SupabaseClient

    var sessionChanges: AsyncStream<Session?> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(session)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func currentSession() async throws -> Session? {
        try? await client.auth.session
    }

    func sendMagicLink(email: String, redirectTo: URL) async throws {
        try await client.auth.signInWithOTP(email: email, redirectTo: redirectTo)
    }

    func handleCallback(_ url: URL) async throws {
        try await client.auth.session(from: url)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }
}
