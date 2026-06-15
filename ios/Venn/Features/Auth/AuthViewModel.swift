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
    }

    /// Resend is gated behind a cooldown so an impatient tap-storm doesn't
    /// burn through the server-side rate limit (and so the button honestly
    /// communicates that email takes a moment to arrive).
    static let resendCooldown: TimeInterval = 30

    var email = ""
    var state: State = .idle
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
        if case .sending = state { return false }
        if case .valid = Sanitize.email(email) { return true }
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
    }
}
