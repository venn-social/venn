#if DEBUG
    import Foundation
    import Supabase
    import Testing
    @testable import Venn

    @MainActor
    struct AuthStateTests {
        /// When anonymous sign-ins are disabled (the service throws), the
        /// guest bypass reports failure and leaves auth state untouched —
        /// it must NOT fabricate a session. A fabricated session can't pass
        /// RLS, so every write would fail with opaque errors (the
        /// onboarding bug of 2026-06-12).
        @Test
        func enterGuestSessionReportsFailureWithoutFabricatingASession() async {
            let service = FakeAuthService()
            service.signInAnonymouslyResult = .failure(NSError(domain: "test", code: 1))
            let state = AuthState(service: service)
            state.status = .signedOut

            let ok = await state.enterGuestSession()

            #expect(ok == false)
            #expect(state.status == .signedOut)
        }

        /// Success path: the service call goes through; the real session
        /// arrives later via the auth-state listener (not asserted here).
        @Test
        func enterGuestSessionSucceedsWhenAnonymousSignInsAreEnabled() async {
            let service = FakeAuthService()
            let state = AuthState(service: service)

            let ok = await state.enterGuestSession()

            #expect(ok == true)
        }
    }
#endif
