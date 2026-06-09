#if DEBUG
    import Foundation
    import Supabase
    import Testing
    @testable import Venn

    @MainActor
    struct AuthStateTests {
        /// When anonymous sign-ins are disabled (the service throws), the
        /// DEBUG guest bypass still lands the app in a signed-in state via the
        /// local fallback session.
        @Test
        func enterGuestSessionFallsBackToDebugSession() async {
            let service = FakeAuthService()
            service.signInAnonymouslyResult = .failure(NSError(domain: "test", code: 1))
            let state = AuthState(service: service)

            await state.enterGuestSession()

            guard case let .signedIn(session) = state.status else {
                Issue.record("expected .signedIn, got \(state.status)")
                return
            }
            #expect(session.user.isAnonymous == true)
        }
    }
#endif
