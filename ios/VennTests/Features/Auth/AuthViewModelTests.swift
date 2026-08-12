import Foundation
import Supabase
import Testing
@testable import Venn

@MainActor
struct AuthViewModelTests {
    // MARK: - canSubmit

    @Test
    func canSubmitFalseWhenEmailEmpty() {
        let viewModel = makeViewModel()
        #expect(viewModel.canSubmit == false)
    }

    @Test
    func canSubmitFalseWhenEmailInvalid() {
        let viewModel = makeViewModel()
        viewModel.email = "not-an-email"
        #expect(viewModel.canSubmit == false)
    }

    @Test
    func canSubmitTrueWhenEmailValid() {
        let viewModel = makeViewModel()
        viewModel.email = "charles@example.com"
        #expect(viewModel.canSubmit == true)
    }

    @Test
    func canSubmitFalseWhileSending() {
        let viewModel = makeViewModel()
        viewModel.email = "charles@example.com"
        viewModel.state = .sending
        #expect(viewModel.canSubmit == false)
    }

    // MARK: - submit happy path

    @Test
    func submitSendsMagicLinkAndTransitionsToSent() async {
        let service = FakeAuthService()
        let redirect = URL(staticString: "social.venn.app://auth-callback")
        let viewModel = AuthViewModel(service: service, redirectURL: redirect)
        viewModel.email = "Charles@Example.com"

        await viewModel.submit()

        #expect(viewModel.state == .sent)
        #expect(service.lastMagicLinkEmail == "charles@example.com")
        #expect(service.lastMagicLinkURL == redirect)
    }

    @Test
    func submitSetsSendingBeforeSent() async {
        // The view-model briefly sits at .sending while the network call is
        // in flight. We can't easily observe the intermediate state in a
        // single await, so we use a service that suspends until released.
        let service = FakeAuthService()
        service.holdSendMagicLink = true
        let viewModel = AuthViewModel(
            service: service,
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        )
        viewModel.email = "charles@example.com"

        let task = Task { await viewModel.submit() }
        // Give the task a tick to enter `submit` and set `.sending`.
        try? await Task.sleep(nanoseconds: 10_000_000)
        #expect(viewModel.state == .sending)

        service.releaseSendMagicLink()
        await task.value
        #expect(viewModel.state == .sent)
    }

    // MARK: - submit failure paths

    @Test
    func submitWithInvalidEmailGoesToError() async {
        let viewModel = makeViewModel()
        viewModel.email = "not-an-email"

        await viewModel.submit()

        #expect(viewModel.state == .error(.invalidEmail))
    }

    @Test
    func submitWithEmptyEmailGoesToError() async {
        let viewModel = makeViewModel()
        viewModel.email = ""

        await viewModel.submit()

        #expect(viewModel.state == .error(.invalidEmail))
    }

    @Test
    func submitWithNonAppErrorFallsBackToSendFailed() async {
        // A raw Error (not an AppError) goes down the catch-all branch.
        struct Boom: Error {}
        let viewModel = makeViewModel(failingWith: Boom())
        viewModel.email = "charles@example.com"

        await viewModel.submit()

        #expect(viewModel.state == .error(.sendFailed))
    }

    @Test
    func submitWithAppErrorNetworkMapsToOffline() async {
        let viewModel = makeViewModel(failingWith: AppError.network)
        viewModel.email = "charles@example.com"

        await viewModel.submit()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func submitWithAppErrorRateLimitedMapsToRateLimited() async {
        let viewModel = makeViewModel(failingWith: AppError.rateLimited)
        viewModel.email = "charles@example.com"

        await viewModel.submit()

        #expect(viewModel.state == .error(.rateLimited))
    }

    @Test
    func submitWithAppErrorUnknownMapsToSendFailed() async {
        let viewModel = makeViewModel(failingWith: AppError.unknown(message: "x"))
        viewModel.email = "charles@example.com"

        await viewModel.submit()

        #expect(viewModel.state == .error(.sendFailed))
    }

    // MARK: - reset

    @Test
    func resetReturnsToIdle() {
        let viewModel = makeViewModel()
        viewModel.state = .sent
        viewModel.reset()
        #expect(viewModel.state == .idle)
    }

    // MARK: - helpers

    // MARK: - resend cooldown

    @Test
    func resendLockedDuringCooldownThenUnlocks() async {
        let service = FakeAuthService()
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let viewModel = AuthViewModel(
            service: service,
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        ) { fakeNow }
        viewModel.email = "charles@example.com"
        await viewModel.submit()
        #expect(viewModel.state == .sent)
        #expect(viewModel.canResend == false)
        #expect(viewModel.resendSecondsRemaining == 30)

        fakeNow = fakeNow.addingTimeInterval(31)
        #expect(viewModel.canResend == true)
        #expect(viewModel.resendSecondsRemaining == 0)
    }

    @Test
    func cooldownRoundsUpSoTheButtonNeverUnderstatesTheWait() async {
        // At 29.5s elapsed there is half a second left. Showing "0s" while
        // the control is still disabled reads as broken. Mirrors web's
        // resendSecondsRemaining rounding case.
        let service = FakeAuthService()
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let viewModel = AuthViewModel(
            service: service,
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        ) { fakeNow }
        viewModel.email = "charles@example.com"
        await viewModel.submit()

        fakeNow = fakeNow.addingTimeInterval(29.5)

        #expect(viewModel.resendSecondsRemaining == 1)
        #expect(viewModel.canResend == false)
    }

    @Test
    func aClockThatJumpsBackwardsExtendsTheWaitRatherThanBreaking() async {
        // System clock changes and DST have both produced negative elapsed
        // time in the wild. Waiting longer is the safe direction; going
        // negative would unlock resend immediately and burn the send limit.
        let service = FakeAuthService()
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let viewModel = AuthViewModel(
            service: service,
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        ) { fakeNow }
        viewModel.email = "charles@example.com"
        await viewModel.submit()

        fakeNow = fakeNow.addingTimeInterval(-60)

        #expect(viewModel.resendSecondsRemaining == 90)
        #expect(viewModel.canResend == false)
    }

    @Test
    func resendSendsAgainAndRestartsCooldown() async {
        let service = FakeAuthService()
        var fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let viewModel = AuthViewModel(
            service: service,
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        ) { fakeNow }
        viewModel.email = "charles@example.com"
        await viewModel.submit()
        fakeNow = fakeNow.addingTimeInterval(31)

        await viewModel.resend()

        #expect(service.sendCount == 2)
        #expect(viewModel.state == .sent)
        #expect(viewModel.canResend == false)
    }

    @Test
    func resendIgnoredWhileCooldownActive() async {
        let service = FakeAuthService()
        let fakeNow = Date(timeIntervalSince1970: 1_000_000)
        let viewModel = AuthViewModel(
            service: service,
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        ) { fakeNow }
        viewModel.email = "charles@example.com"
        await viewModel.submit()

        await viewModel.resend()

        #expect(service.sendCount == 1)
    }

    @Test
    func resetClearsCooldownState() async {
        let viewModel = makeViewModel()
        viewModel.email = "charles@example.com"
        await viewModel.submit()

        viewModel.reset()

        #expect(viewModel.lastSentAt == nil)
        #expect(viewModel.state == .idle)
    }

    private func makeViewModel() -> AuthViewModel {
        AuthViewModel(
            service: FakeAuthService(),
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        )
    }

    /// Pre-loads the fake to fail with the given error so error-path tests
    /// don't have to repeat the setup boilerplate.
    private func makeViewModel(failingWith error: any Error) -> AuthViewModel {
        let service = FakeAuthService()
        service.sendMagicLinkResult = .failure(error)
        return AuthViewModel(
            service: service,
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        )
    }
}

/// Hand-rolled fake. Records the last call, exposes a "hold" hook so tests
/// can observe the in-flight `.sending` state, and lets each method's result
/// be configured per test.
final class FakeAuthService: AuthServicing, @unchecked Sendable {
    var currentSessionResult: Result<Session?, Error> = .success(nil)
    var sendMagicLinkResult: Result<Void, Error> = .success(())
    var lastMagicLinkEmail: String?
    var lastMagicLinkURL: URL?
    var holdSendMagicLink = false
    private var sendContinuation: CheckedContinuation<Void, Never>?

    var sessionChanges: AsyncStream<Session?> {
        AsyncStream { _ in }
    }

    func currentSession() async throws -> Session? {
        try currentSessionResult.get()
    }

    private(set) var sendCount = 0

    func sendMagicLink(email: String, redirectTo: URL) async throws {
        sendCount += 1
        lastMagicLinkEmail = email
        lastMagicLinkURL = redirectTo
        if holdSendMagicLink {
            await withCheckedContinuation { cont in sendContinuation = cont }
        }
        try sendMagicLinkResult.get()
    }

    func releaseSendMagicLink() {
        sendContinuation?.resume()
        sendContinuation = nil
    }

    var verifyCodeResult: Result<Void, Error> = .success(())
    private(set) var verifyCount = 0
    var lastVerifiedEmail: String?
    var lastVerifiedToken: String?

    func verifyCode(email: String, token: String) async throws {
        verifyCount += 1
        lastVerifiedEmail = email
        lastVerifiedToken = token
        try verifyCodeResult.get()
    }

    // periphery:ignore - protocol-conformance stub for tests that don't
    // exercise the deep-link callback path.
    func handleCallback(_: URL) async throws {}

    func signOut() async throws {}

    var signInAnonymouslyResult: Result<Void, Error> = .success(())

    func signInAnonymously() async throws {
        try signInAnonymouslyResult.get()
    }
}

/// The emailed-code fallback, which iOS gained to match web's sign-in.
@MainActor
struct AuthCodeVerificationTests {
    private func makeViewModel(
        _ service: FakeAuthService
    ) -> AuthViewModel {
        AuthViewModel(
            service: service,
            redirectURL: URL(staticString: "social.venn.app://auth-callback")
        )
    }

    @Test
    func verifyingSendsTheNormalizedEmailAndTypedCode() async {
        let service = FakeAuthService()
        let viewModel = makeViewModel(service)
        viewModel.email = "  Charles@Example.COM "
        viewModel.state = .sent
        viewModel.code = "123456"

        await viewModel.verifyCode()

        #expect(service.verifyCount == 1)
        // Sanitize normalizes before the request, exactly as sending does —
        // a code issued for the normalized address will not verify against
        // whatever casing the user typed.
        #expect(service.lastVerifiedEmail == "charles@example.com")
        #expect(service.lastVerifiedToken == "123456")
    }

    @Test
    func surroundingWhitespaceIsTrimmedFromAPastedCode() async {
        let service = FakeAuthService()
        let viewModel = makeViewModel(service)
        viewModel.email = "charles@example.com"
        viewModel.state = .sent
        viewModel.code = "  123456 "

        await viewModel.verifyCode()

        #expect(service.lastVerifiedToken == "123456")
    }

    @Test
    func aRejectedCodeReturnsToSentSoTheFieldStaysOnScreen() async {
        // Going to `.error` would swap the inbox panel for the email form,
        // taking the code field away at the moment it is needed.
        let service = FakeAuthService()
        service.verifyCodeResult = .failure(AppError.unknown(message: "bad code"))
        let viewModel = makeViewModel(service)
        viewModel.email = "charles@example.com"
        viewModel.state = .sent
        viewModel.code = "000000"

        await viewModel.verifyCode()

        #expect(viewModel.state == .sent)
        #expect(viewModel.verifyFailed)
    }

    @Test
    func retryingClearsThePreviousRejection() async {
        let service = FakeAuthService()
        service.verifyCodeResult = .failure(AppError.unknown(message: "bad code"))
        let viewModel = makeViewModel(service)
        viewModel.email = "charles@example.com"
        viewModel.state = .sent
        viewModel.code = "000000"
        await viewModel.verifyCode()
        #expect(viewModel.verifyFailed)

        service.verifyCodeResult = .success(())
        viewModel.code = "123456"
        await viewModel.verifyCode()

        #expect(!viewModel.verifyFailed)
    }

    @Test
    func anEmptyCodeIsNotSent() async {
        let service = FakeAuthService()
        let viewModel = makeViewModel(service)
        viewModel.email = "charles@example.com"
        viewModel.state = .sent
        viewModel.code = "   "

        await viewModel.verifyCode()

        #expect(service.verifyCount == 0)
    }

    @Test
    func verifyIsDisabledUntilSomethingIsTyped() {
        let viewModel = makeViewModel(FakeAuthService())
        #expect(!viewModel.canVerify)

        viewModel.code = "1"
        #expect(viewModel.canVerify)
    }

    @Test
    func startingOverClearsTheCodeAndAnyRejection() async {
        let service = FakeAuthService()
        service.verifyCodeResult = .failure(AppError.unknown(message: "bad code"))
        let viewModel = makeViewModel(service)
        viewModel.email = "charles@example.com"
        viewModel.state = .sent
        viewModel.code = "000000"
        await viewModel.verifyCode()

        viewModel.reset()

        #expect(viewModel.code.isEmpty)
        #expect(!viewModel.verifyFailed)
        #expect(viewModel.state == .idle)
    }
}
