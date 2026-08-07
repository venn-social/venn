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

    // periphery:ignore - call site pending; magic-link deep-link wiring is
    // tracked separately (rate-limit-blocked on Supabase email).
    /// Completes sign-in from the URL the magic-link email opened the app
    /// with. Called from `App.onOpenURL`.
    func handleCallback(_ url: URL) async throws

    /// Clears the local session and revokes the refresh token server-side.
    func signOut() async throws

    /// Signs in as an anonymous guest — a real Supabase session with no
    /// email, so the app routes straight into the signed-in experience.
    /// Backs the DEBUG "Continue as guest" affordance that skips the
    /// magic-link flow while it's being finalized. Requires anonymous
    /// sign-ins to be enabled in the Supabase project's auth settings.
    func signInAnonymously() async throws
}

/// Production implementation backed by `supabase-swift`'s `GoTrueClient`.
///
/// Throwing methods funnel third-party errors through `AppError.from(_:)`
/// so callers see a single semantic error type (ADR 0006). The exception
/// is `currentSession()` — that method swallows errors via `try?` because
/// "couldn't read session" and "no session" are both treated as
/// signed-out at the call site, so there's no error to surface.
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
        do {
            try await client.auth.signInWithOTP(email: email, redirectTo: redirectTo)
        } catch {
            throw AppError.from(error)
        }
    }

    func handleCallback(_ url: URL) async throws {
        do {
            try await client.auth.session(from: url)
        } catch {
            throw AppError.from(error)
        }
    }

    func signOut() async throws {
        do {
            // .local, not the SDK's .global default. "Sign out" on this
            // device means this device; global would also end the session
            // on the user's phone, which is a "sign out everywhere"
            // security action and belongs behind its own labelled control.
            try await client.auth.signOut(scope: .local)
        } catch {
            throw AppError.from(error)
        }
    }

    func signInAnonymously() async throws {
        do {
            try await client.auth.signInAnonymously()
        } catch {
            throw AppError.from(error)
        }
    }
}
