import Foundation
import Testing
@testable import Venn

struct RateLimiterTests {
    @Test func allowsUpToMaxCallsWithinWindow() async throws {
        let limiter = RateLimiter(limit: .init(maxCalls: 3, windowSeconds: 1))
        let now = Date()
        try await limiter.check(now: now)
        try await limiter.check(now: now)
        try await limiter.check(now: now)
    }

    @Test func rejectsAfterLimit() async throws {
        let limiter = RateLimiter(limit: .init(maxCalls: 2, windowSeconds: 10))
        let now = Date()
        try await limiter.check(now: now)
        try await limiter.check(now: now)

        await #expect(throws: RateLimiter.LimitExceeded.self) {
            try await limiter.check(now: now)
        }
    }

    @Test func releasesAfterWindow() async throws {
        let limiter = RateLimiter(limit: .init(maxCalls: 1, windowSeconds: 60))
        let t0 = Date()
        try await limiter.check(now: t0)

        let later = t0.addingTimeInterval(61)
        try await limiter.check(now: later) // window cleared, succeeds
    }

    @Test func reportsRetryAfter() async throws {
        let limiter = RateLimiter(limit: .init(maxCalls: 1, windowSeconds: 10))
        let t0 = Date()
        try await limiter.check(now: t0)

        do {
            try await limiter.check(now: t0.addingTimeInterval(3))
            Issue.record("Expected check() to throw LimitExceeded")
        } catch let error as RateLimiter.LimitExceeded {
            // 10s window, oldest at t0, now t0+3 → retryAfter ≈ 7
            #expect(abs(error.retryAfter - 7) < 0.001)
        }
    }

    @Test func isAllowedDoesNotConsumeBudget() async {
        let limiter = RateLimiter(limit: .init(maxCalls: 2, windowSeconds: 10))
        let now = Date()
        let firstCheck = await limiter.isAllowed(now: now)
        let secondCheck = await limiter.isAllowed(now: now)
        #expect(firstCheck == true)
        #expect(secondCheck == true)
    }

    @Test func isAllowedReturnsFalseWhenFull() async throws {
        let limiter = RateLimiter(limit: .init(maxCalls: 1, windowSeconds: 10))
        let now = Date()
        try await limiter.check(now: now)
        let allowed = await limiter.isAllowed(now: now)
        #expect(allowed == false)
    }

    @Test func resetClears() async throws {
        let limiter = RateLimiter(limit: .init(maxCalls: 1, windowSeconds: 60))
        let now = Date()
        try await limiter.check(now: now)
        let blocked = await limiter.isAllowed(now: now)
        #expect(blocked == false)

        await limiter.reset()
        let allowedAfterReset = await limiter.isAllowed(now: now)
        #expect(allowedAfterReset == true)
    }
}
