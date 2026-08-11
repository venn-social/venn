import Supabase
import SwiftUI

#if DEBUG
    /// DEBUG-only harness that renders the real sign-in screen against a
    /// deterministic in-memory stub, so the magic-link send/error/resend UI
    /// can be UI-tested without hitting Supabase's email rate limit. Booted
    /// by the `-previewAuth` launch arg (see `RootView`).
    ///
    /// The stub email `blocked@example.com` simulates a rate-limited send so
    /// a UI test can exercise the error branch deterministically; every
    /// other valid address succeeds.
    struct AuthPreviewView: View {
        var body: some View {
            AuthView(viewModel: AuthViewModel(
                service: StubAuthService(),
                redirectURL: URL(staticString: "social.venn.app://auth-callback")
            ))
            .environment(AuthState(service: StubAuthService()))
        }
    }

    private struct StubAuthService: AuthServicing {
        var sessionChanges: AsyncStream<Session?> {
            AsyncStream { $0.finish() }
        }

        func currentSession() async throws -> Session? {
            nil
        }

        func sendMagicLink(email: String, redirectTo _: URL) async throws {
            if email == "blocked@example.com" {
                throw AppError.rateLimited
            }
        }

        func verifyCode(email _: String, token _: String) async throws {}
        func handleCallback(_: URL) async throws {}
        func signOut() async throws {}
        func signInAnonymously() async throws {}
    }

    #Preview {
        AuthPreviewView()
    }
#endif
