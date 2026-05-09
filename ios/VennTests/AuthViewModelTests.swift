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

    func sendMagicLink(email: String, redirectTo: URL) async throws {
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

    // periphery:ignore - protocol-conformance stub for tests that don't
    // exercise the deep-link callback path.
    func handleCallback(_: URL) async throws {}

    func signOut() async throws {}
}
