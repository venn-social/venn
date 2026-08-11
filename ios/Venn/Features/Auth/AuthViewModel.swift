import Foundation
import Observation

/// Drives the magic-link sign-in screen. Holds the email field, validates
/// it via `Sanitize.email`, and tracks the four states the screen can be
/// in: idle, sending, sent, error.
///
/// Keeps zero references to SwiftUI types so it's easy to unit-test against
/// a fake `AuthServicing`.
@MainActor
@Observable
final class AuthViewModel {
    enum State: Equatable {
        case idle
        case sending
        case sent
        case verifying
        case error(ErrorReason)
    }

    /// The view layer maps these to localized copy. Keeping the cases
    /// (rather than user-facing strings) here keeps the view-model free of
    /// `LocalizedStringKey` and easy to test.
    enum ErrorReason: Equatable {
        case invalidEmail
        case offline
        case rateLimited
        case sendFailed
        /// The typed code was wrong or expired. Distinct from `sendFailed`
        /// because the recovery is different: retype, don't resend.
        case badCode
    }

    /// Resend is gated behind a cooldown so an impatient tap-storm doesn't
    /// burn through the server-side rate limit (and so the button honestly
    /// communicates that email takes a moment to arrive).
    static let resendCooldown: TimeInterval = 30

    var email = ""
    /// The numeric code from the sign-in email — the fallback for when the
    /// link itself does not work.
    var code = ""
    var state: State = .idle
    /// Set when a code is rejected, cleared on the next attempt. Separate
    /// from `state` so the inbox panel keeps rendering underneath it.
    var verifyFailed = false
    private(set) var lastSentAt: Date?

    private let service: any AuthServicing
    private let redirectURL: URL
    private let now: () -> Date

    /// `now` is injectable so cooldown tests don't sleep.
    init(
        service: any AuthServicing,
        redirectURL: URL,
        now: @escaping () -> Date = { Date() }
    ) {
        self.service = service
        self.redirectURL = redirectURL
        self.now = now
    }

    /// Enabled once something has been typed and no verification is in
    /// flight. Mirrors web's `code.length === 0` guard.
    var canVerify: Bool {
        state != .verifying && !code.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Exchange the emailed code for a session. On success the auth-state
    /// listener flips `status` and the app routes itself; there is nothing
    /// to do here but stop showing a spinner.
    func verifyCode() async {
        let token = code.trimmingCharacters(in: .whitespaces)
        guard !token.isEmpty,
              case let .valid(normalized) = Sanitize.email(email)
        else {
            state = .error(.badCode)
            return
        }

        verifyFailed = false
        state = .verifying
        do {
            try await service.verifyCode(email: normalized, token: token)
        } catch {
            // Back to `.sent`, not `.error`: the inbox panel with the code
            // field has to stay on screen for a retype to be possible.
            state = .sent
            verifyFailed = true
        }
    }

    /// Seconds until "Resend link" unlocks (0 = ready). The view ticks a
    /// `TimelineView` against this.
    var resendSecondsRemaining: Int {
        guard let lastSentAt else { return 0 }
        let elapsed = now().timeIntervalSince(lastSentAt)
        return max(0, Int((Self.resendCooldown - elapsed).rounded(.up)))
    }

    var canResend: Bool {
        state == .sent && resendSecondsRemaining == 0
    }

    /// True when the email passes validation and we're not mid-send. The
    /// view binds the submit button's disabled state to this.
    var canSubmit: Bool {
        if case .sending = state {
            return false
        }
        if case .valid = Sanitize.email(email) {
            return true
        }
        return false
    }

    /// Validate the email, flip to `.sending`, ask the service to send the
    /// magic link, then transition to `.sent` (success) or `.error`.
    func submit() async {
        guard case let .valid(normalized) = Sanitize.email(email) else {
            state = .error(.invalidEmail)
            return
        }
        state = .sending
        do {
            try await service.sendMagicLink(email: normalized, redirectTo: redirectURL)
            lastSentAt = now()
            state = .sent
        } catch let error as AppError {
            state = .error(reason(for: error))
        } catch {
            state = .error(.sendFailed)
        }
    }

    /// Send the link again to the same address. Only valid from `.sent`
    /// once the cooldown has elapsed; failures drop back to the error
    /// branch like a first send would.
    func resend() async {
        guard canResend,
              case let .valid(normalized) = Sanitize.email(email)
        else { return }
        do {
            try await service.sendMagicLink(email: normalized, redirectTo: redirectURL)
            lastSentAt = now()
        } catch let error as AppError {
            state = .error(reason(for: error))
        } catch {
            state = .error(.sendFailed)
        }
    }

    /// Translate a service-layer `AppError` into a UI-layer `ErrorReason`.
    /// View renders different copy + affordances per reason.
    private func reason(for error: AppError) -> ErrorReason {
        switch error {
        case .network: .offline
        case .rateLimited: .rateLimited
        case .unauthorized, .validation, .server, .unknown: .sendFailed
        }
    }

    /// Return to `.idle` — used by the "try a different email" affordance
    /// on the `.sent` and `.error` screens.
    func reset() {
        state = .idle
        lastSentAt = nil
        code = ""
        verifyFailed = false
    }
}
