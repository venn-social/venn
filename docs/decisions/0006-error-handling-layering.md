# 0006 — Error handling: `AppError` at the service boundary, `State.error(reason)` at the view boundary

- **Status:** Accepted
- **Date:** 2026-05-08
- **Deciders:** Charles Salomon

## Context

The codebase has an inconsistency between what's documented and what ships. `docs/CODING_STANDARDS.md` describes a single-funnel pattern: define an `AppError` enum, view-models hold `var error: AppError?`, views render an `.alert(...)` over it. The actual code uses a different pattern: every view-model has its own `enum State { idle, loading, success(T), error(Reason) }` with a domain-specific `Reason` enum (e.g. `AuthViewModel.ErrorReason { invalidEmail, sendFailed }`).

Both patterns have merit. The single-funnel pattern is simple, uniform across the app, and lets a top-level alert handler render any error. The state-machine pattern lets the view pattern-match and render _different visual treatments per error reason_ (a "check your email format" inline label vs a full-screen "couldn't load — retry?" empty state) — and the explicit `enum State` lifecycle makes the view's render logic exhaustive.

There's also a missing piece: services today throw whatever the Supabase SDK throws (a mix of `PostgrestError`, `URLError`, `AuthError`, etc.). The view-model catches as `Error` and degrades to a Reason. There's no shared, semantic error type at the service boundary, which means each view-model re-derives "is this a network error or a 401 or a validation error?" from string-typed messages.

We need to align the docs to reality and fill the gap at the service boundary.

## Decision

Two error types, two boundaries:

1. **`AppError` at the service boundary.** Every `<Feature>Service` method throws `AppError`, never raw third-party errors. Services map Supabase / network / auth errors to semantic `AppError` cases at the call site.
2. **`<ViewModel>.State.error(Reason)` at the view boundary.** Every view-model has an `enum State` with an `error(Reason)` case. The `Reason` enum is feature-specific and _captures only the reasons that surface in the UI_ (typically: validation reasons, retryable failures, terminal failures).

The view-model's job is to translate: catch `AppError`, decide which `Reason` it maps to (validation vs network vs auth vs server vs unknown), set `state = .error(.<reason>)`. Views pattern-match on `state` and render appropriate UI per reason — inline error label for validation, full-screen retry for network, "session expired" sheet for auth.

`AppError` shape (as implemented in `ios/Venn/Models/AppError.swift`):

```swift
enum AppError: Error, Equatable {
    case network            // connectivity, timeout, DNS
    case unauthorized       // 401 / session expired / RLS denied
    case validation(String) // 4xx with a server message we should show
    case rateLimited
    case server             // 5xx
    case unknown(message: String)
}
```

`Sendable` conformance is inferred automatically — Swift 6 synthesises it for internal value types whose payloads are all `Sendable`, and `String` is. We deliberately use `unknown(message: String)` rather than `unknown(Error)` so this synthesis works; an `Error` payload (which is not `Sendable`) would block it under strict concurrency. The original error's `localizedDescription` is captured at the boundary.

Mapping happens once, at the service boundary:

```swift
struct ProfileService: ProfileServicing {
    func profile(for userID: UUID) async throws -> UserProfile {
        do {
            return try await client.from("profiles").select().eq("id", value: userID).single().execute().value
        } catch {
            throw AppError.from(error)  // mapper that inspects the underlying type
        }
    }
}
```

`AppError.from(_:)` is a pure function that takes any `Error` and returns the right `AppError` case — the only place any third-party error type is referenced. Adding a new mapping (e.g. handling a new Postgrest error code) is a one-line change there.

The `enum State` pattern stays as-is in view-models. `CODING_STANDARDS.md` is updated to match this two-tier shape; the `var error: AppError?` example there is incorrect and gets removed.

## Consequences

- **Easier:** view-models never re-derive "what kind of error was this?" from inspection — the service already classified it. Adding a new error class (e.g. `rateLimited`) once in `AppError` makes it available to every view-model. View-side rendering stays exhaustive — the compiler still forces views to handle every `Reason` case.
- **Harder:** introduces an extra hop (`AppError.from` mapper) at every service. Worth the cost — the alternative is each view-model parsing third-party error shapes inline.
- **Committed to:** services never let a non-`AppError` escape. View-models never throw — they catch and set `state`. Views never see `AppError` directly; they see `Reason`.
- **Migration:** existing view-models stay; the mapper and a small refactor of each `<Feature>Service` is a one-PR-per-service migration. Net code change is small.

## Alternatives considered

- **Single `var error: AppError?` on each view-model + `.alert(...)` at the view.** Simpler API, one-funnel rendering, fewer types. We lose the per-reason visual treatment that makes the UI feel responsive (e.g. inline "invalid email" hint vs a modal alert). Most apps do this; we want to do better.
- **Throw raw third-party errors all the way up.** Zero abstraction. View-models become couplers between view code and Supabase SDK error shapes. Refactoring the SDK or swapping a library means touching every view-model.
- **A single `enum AppState<T> { idle, loading, success(T), error(AppError) }` reused by every view-model.** Tempting (DRY!) but loses the feature-specific `Reason` cases that views pattern-match on. The reasons aren't generic — `AuthViewModel.ErrorReason.invalidEmail` doesn't make sense outside auth.
