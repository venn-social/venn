# 0005 — Service-protocol-with-fake for testability

- **Status:** Proposed
- **Date:** 2026-05-08
- **Deciders:** Charles Salomon

## Context

Every Supabase-touching surface in the app is wrapped in a feature service (`AuthService`, `ProfileService`, `FeedService`, …). View-models depend on those services. To keep view-model tests fast and deterministic — no network, no auth flow, no test database to seed — we need a way to substitute a controllable fake at test time.

Three idiomatic Swift patterns for that substitution:

1. **Protocol + concrete + fake.** The service is a protocol. Production has a `struct` conforming to it; tests have a hand-rolled fake conforming to it. The view-model takes `any Servicing` in its initializer.
2. **Function injection.** The view-model takes closures (`fetchProfile: (UUID) async throws -> UserProfile`) instead of a service object. Tests pass test-specific closures.
3. **Mock framework.** A library like Mockingbird auto-generates mocks from protocols at build time; tests configure expectations on the generated mocks.

The codebase already uses pattern 1 consistently — `AuthServicing`, `ProfileServicing`, with `FakeAuthService`, `FakeProfileService` in the test target. This ADR documents the choice so contributors don't propose mock-framework adoption or function-injection refactors.

## Decision

Use **protocol + concrete + fake**. Every service that has more than one possible implementation (production + test) defines a protocol named `<Feature>Servicing`, with a struct named `<Feature>Service` as the production implementation, and a class named `Fake<Feature>Service` in the test target as the controllable test double.

Conventions:

- Protocol naming: `<Feature>Servicing` (gerund). `AuthServicing`, `ProfileServicing`. The gerund makes it clear it's an interface, not a type.
- The protocol is `Sendable`. The production struct conforms naturally; fakes use `final class … @unchecked Sendable` because they hold mutable test state (recorded calls, configured results).
- The fake exposes `result: Result<T, Error>` (or `<method>Result`) for each method; tests set the result, run the method, assert on the recorded calls and the resulting view-model state. This pattern is illustrated in `ios/VennTests/ProfileViewModelTests.swift` and friends.
- View-models depend on `any <Feature>Servicing`, never on the concrete struct. The same view-model unit-tests with the fake and ships with the real service.
- Fakes live in the test target only. Production code never imports test doubles.

If a service has only one implementation and is trivially testable (pure functions, no I/O), it doesn't need a protocol. `Sanitize` and `ExternalAPI` are static-method enums — testable without an extra layer.

## Consequences

- **Easier:** every view-model can be unit-tested in milliseconds with no network, no Supabase test instance, no mock library to configure. Tests read top-to-bottom: `set up fake → run method → assert state`. Compile-time guarantees that the fake matches the protocol surface — when we add a new method to the protocol, the test target fails to build until the fake catches up.
- **Harder:** every service touchpoint costs one extra type (the protocol) and one extra fake to maintain. Protocols with many methods pull in more boilerplate than a function-injection equivalent for very small services.
- **Committed to:** the `Servicing` / `Service` / `FakeService` triple as the standard. Switching to a mock framework later means rewriting every test that sets `fake.result = …`. Switching to function injection means rewriting every view-model's init signature.

## Alternatives considered

- **Function injection.** Lighter for 1–2-method services, but punitive for anything broader — the view-model init signature explodes. Loses the natural grouping of related methods. Doesn't scale to services with state (sessions, subscriptions).
- **Mockingbird (or any auto-mock framework).** Generates expectation-style mocks at build time. Adds a build-time codegen step, a learning curve for the expectation DSL, and a class of test failures ("expectation not satisfied") that don't read as cleanly as `#expect(fake.recorded == [...])`. Useful at scale; overkill at our size.
- **Protocol witnesses (functional pattern).** The service is a struct of closures. Testing means constructing a witness with test closures. Idiomatic in Point-Free's ecosystem; cognitively heavier than the protocol pattern for our team.
- **No abstraction — test against a real Supabase test instance.** The integration tests we'd write are valuable but slow (seconds per test, flaky on network). Keep them as a separate, smaller suite for end-to-end confidence; don't make them the unit-test default.
