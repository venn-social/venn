import Foundation

/// Sliding-window rate limiter for client-side UX feedback only.
///
/// IMPORTANT — this is not a security boundary. Real rate limiting MUST live
/// server-side (Postgres `rl_check` function called by Edge Functions / RPCs;
/// see `docs/CODING_STANDARDS.md` § Rate limiting). Anything that runs in the
/// app on the user's device can be bypassed by a determined attacker.
///
/// Use cases:
///   - Stop accidental double-taps of "post" buttons.
///   - Throttle expensive search queries to avoid hammering the backend.
///   - Show a friendly "slow down" toast before the server returns 429.
///
/// Modelled as an `actor` so concurrent callers across `Task`s see consistent
/// state under `SWIFT_STRICT_CONCURRENCY=complete`.
actor RateLimiter {
    /// Configuration: how many calls in what window.
    struct Limit: Equatable {
        let maxCalls: Int
        let windowSeconds: TimeInterval

        init(maxCalls: Int, windowSeconds: TimeInterval) {
            precondition(maxCalls >= 1, "maxCalls must be at least 1")
            precondition(windowSeconds > 0, "windowSeconds must be positive")
            self.maxCalls = maxCalls
            self.windowSeconds = windowSeconds
        }
    }

    /// Thrown by `check()` when the window is full.
    struct LimitExceeded: Error, Equatable {
        /// Seconds until the *oldest* recorded call ages out and frees a slot.
        let retryAfter: TimeInterval
    }

    private let limit: Limit
    private var calls: [Date] = []

    init(limit: Limit) {
        self.limit = limit
    }

    /// Records a call against the limiter. Throws `LimitExceeded` if the
    /// window is already full. The `now` parameter is exposed for tests so
    /// they can simulate time without relying on `Date()`.
    func check(now: Date = Date()) throws {
        evict(before: now.addingTimeInterval(-limit.windowSeconds))
        if calls.count >= limit.maxCalls {
            let oldest = calls.first ?? now
            let retryAfter = limit.windowSeconds - now.timeIntervalSince(oldest)
            throw LimitExceeded(retryAfter: max(retryAfter, 0))
        }
        calls.append(now)
    }

    /// Non-mutating: would the next `check()` succeed right now?
    func isAllowed(now: Date = Date()) -> Bool {
        evict(before: now.addingTimeInterval(-limit.windowSeconds))
        return calls.count < limit.maxCalls
    }

    /// Forget every recorded call. Use after a successful retry, on sign-out,
    /// or when the user changes context (e.g., switches profiles).
    func reset() {
        calls.removeAll()
    }

    private func evict(before cutoff: Date) {
        calls.removeAll { $0 < cutoff }
    }
}
