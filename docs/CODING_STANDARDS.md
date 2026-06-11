# Coding Standards

Most of these are enforced by SwiftLint, SwiftFormat, and the Swift compiler. The rest are enforced by reviewers. This doc exists so you know what to expect before you get a "please change this" comment on a PR.

## Anti-patterns we reject

| Pattern                                          | Why it's banned                                                             |
| ------------------------------------------------ | --------------------------------------------------------------------------- |
| Force unwraps (`!`) outside tests                | Crashes the app. Use `guard let` / `if let` / `??`.                         |
| `try!`, `as!`                                    | Same — turns a recoverable error into a crash.                              |
| `class` when `struct` would do                   | Reference semantics make state changes impossible to reason about.          |
| Implicit `self` capture in closures              | Causes retain cycles. Use `[weak self]` for long-lived closures.            |
| Empty `catch {}` blocks                          | Errors silently swallowed are the worst kind of bug.                        |
| Singletons that aren't services                  | Untestable. Inject via `.environment(...)` instead.                         |
| Stringly-typed identifiers (`"feed"`, `"posts"`) | Use enums or constants. Typos compile fine; behavior breaks at runtime.     |
| Long-lived `@State` in views                     | Use a view-model. `@State` is for trivial UI state only.                    |
| Reaching into other features' types              | Features are self-contained. Move the type to `Models/` if it's shared.     |
| `print(...)` left in production code             | Use `Logger` (os_log) or Sentry breadcrumbs. SwiftLint flags this.          |
| Magic numbers                                    | Name them. `let maxAvatarSize: CGFloat = 96` beats `96`.                    |
| Large SwiftUI screen files                       | Hard to review and easy for AI tools to damage. Split sections into files.  |
| Copy-pasted UI shapes                            | Creates inconsistent UX. Extract rows/cards/chips/buttons into components.  |
| Feature UI inside `Components/`                  | Shared components must not depend on feature-specific models or services.   |
| Fake prototype data in production paths          | Confuses real flows. Keep sample UI behind `#if DEBUG` or preview fixtures. |

## Patterns we like

### Value types over reference types

```swift
// Good — struct, immutable by default
struct PostDTO: Decodable, Sendable {
    let id: UUID
    let body: String
    let createdAt: Date
}

// Bad — class without a reason
final class Post {
    var id: UUID
    var body: String
    var createdAt: Date
}
```

Use a `class` only when you need identity (the same instance referenced from two places must reflect the same mutations). View-models marked `@Observable` are the legitimate exception.

### Service methods are async, throwing, and Sendable

```swift
struct FeedService: Sendable {
    let client: SupabaseClient

    func recentPosts(limit: Int = 20) async throws -> [PostDTO] {
        try await client
            .from("posts")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
}
```

The caller decides how to handle the error. The service doesn't catch and swallow.

### View-models are `@MainActor`

```swift
@MainActor
@Observable
final class FeedViewModel {
    var posts: [PostDTO] = []
    var error: AppError?

    private let service: FeedService

    init(service: FeedService) {
        self.service = service
    }

    func load() async {
        do {
            posts = try await service.recentPosts()
        } catch {
            self.error = AppError(error)
        }
    }
}
```

### Views read from view-models, never call services

```swift
// Good
struct FeedView: View {
    @State private var viewModel: FeedViewModel

    var body: some View {
        List(viewModel.posts) { post in PostRow(post: post) }
            .task { await viewModel.load() }
    }
}

// Bad — view doing service work
struct FeedView: View {
    @State private var posts: [PostDTO] = []

    var body: some View {
        List(posts) { post in PostRow(post: post) }
            .task {
                let client = SupabaseClientProvider.shared.client  // ❌
                posts = try? await client.from("posts").select().execute().value ?? []
            }
    }
}
```

### SwiftUI views are small, split, and reusable

Good frontend code is built from named parts. The screen owns navigation and composition; sections, rows, cards, and reusable primitives live in their own files.

```swift
// Good — screen composition is easy to scan
struct ProfileView: View {
    var body: some View {
        Screen {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    ProfileHeaderView(profile: viewModel.profile)
                    ProfileStatsView(stats: viewModel.stats)
                    ProfileLibrarySection(categories: viewModel.categories)
                }
            }
        }
    }
}
```

```swift
// Bad — one screen file becomes a dumping ground for every visual decision
struct ProfileView: View {
    var body: some View {
        ScrollView {
            VStack {
                // 80 lines of header UI
                // 90 lines of stats UI
                // 120 lines of category rows
                // duplicated buttons and hand-tuned padding
            }
        }
    }
}
```

Frontend extraction rules:

- Extract a view when it has a name the product team would understand: `ProfileHeaderView`, `ActivityCard`, `LibraryCategoryCard`, `ExplorerRecommendationCard`.
- Put reusable primitives in `ios/Venn/Components/`. They should accept plain strings, numbers, images, bindings, and closures; they should not import or know feature models.
- Put feature-specific UI in `ios/Venn/Features/<Feature>/`, or in a subfolder when a flow grows (`Library/`, `Settings/`, `Detail/`).
- Keep `private struct` helpers only for truly tiny one-file details. If another screen could plausibly use it, make it a real component file now.
- Use `Theme` tokens for all color, spacing, radius, and type. Never hand-tune a slightly different version of an existing component.
- Use shared iOS interaction primitives before writing new effects: `GlassSurface` / `.vennGlass(...)` for Liquid Glass surfaces, `GlassSegmentedControl` for chip-like segmented choices, `VennPressButtonStyle` for tappable controls, and `.vennScrollDepth()` / `.vennSelectionFeedback(...)` for motion and sensory feedback.
- Prefer composition over flags. If a component has too many booleans, split it into clearer components.
- Keep debug/prototype screens behind `#if DEBUG` and name them `Prototype` or `Preview` so nobody mistakes them for production UX.

## Imports

```swift
// Foundation / SwiftUI / Apple frameworks first.
import Foundation
import SwiftUI

// Third-party SPM packages alphabetically.
import PostHog
import Sentry
import Supabase
```

Internal modules don't need explicit imports — everything in the `Venn` target is in the same module.

`@testable import Venn` lives at the bottom of test files (SwiftFormat enforces).

## Comments

Default to no comments. Only write one when the **why** is non-obvious. Examples that earn their keep:

```swift
// Hash with SHA-256 instead of MD5 — Apple deprecated MD5 in iOS 13.
let digest = SHA256.hash(data: payload)

// Postgres CHECK constraint enforces this server-side; the client check is just
// for UX feedback.
guard handle.count >= 3 else { return .invalid(.tooShort) }
```

Don't write comments that restate the code:

```swift
// Bad — restates what the code says
// Calls the service to fetch posts.
let posts = try await service.recentPosts()
```

Don't reference the current task, fix, or PR ("added for the X flow", "fixes issue #123"). That belongs in the commit message.

## Error handling

Two boundaries, two error shapes. See ADR [0006 — error handling layering](./decisions/0006-error-handling-layering.md) for the full reasoning.

**At the service boundary**: every `<Feature>Service` method throws [`AppError`](../ios/Venn/Models/AppError.swift) (`Sendable`, `Equatable`, semantic). The mapper `AppError.from(_:)` translates Supabase / `URLError` / unknown errors into the right case. Add new mappings there, not at call sites.

```swift
struct ProfileService: ProfileServicing {
    func profile(for userID: UUID) async throws -> UserProfile {
        do {
            return try await client.from("profiles").select().eq("id", value: userID)
                .single().execute().value
        } catch {
            throw AppError.from(error)
        }
    }
}
```

**At the view-model boundary**: each view-model owns an `enum State` with an `error(Reason)` case. The `Reason` enum is feature-specific and only carries reasons that surface in the UI (validation, retryable, terminal). The view-model catches `AppError` and translates it into one of its `Reason` cases.

```swift
@MainActor @Observable
final class ProfileViewModel {
    enum State: Equatable {
        case loading
        case loaded(UserProfile)
        case error(Reason)
    }
    enum Reason: Equatable { case offline, notFound, unknown }

    private(set) var state: State = .loading
    private let service: any ProfileServicing

    func load() async {
        state = .loading
        do {
            state = .loaded(try await service.profile(for: userID))
        } catch let error as AppError {
            state = .error(reason(for: error))
        } catch {
            state = .error(.unknown)
        }
    }

    private func reason(for error: AppError) -> Reason {
        switch error {
        case .network: .offline
        case .validation, .server, .unauthorized, .rateLimited, .unknown: .unknown
        }
    }
}
```

The view pattern-matches on `state` and renders per-`Reason` UI — inline error label for validation, full-screen retry for offline, "session expired" sheet for auth, etc. Views never see `AppError` directly.

## Tests

- One test file per type under test: `FeedServiceTests.swift`, `SanitizeTests.swift`.
- Use Swift Testing (`@Test func name()`), not XCTest, for new tests. UI tests stay on XCTest because XCUITest hasn't migrated.
- Test the public surface, not implementation details. If it's `private`, you don't test it.
- Each test is independent. Use `init` / `deinit` (in a `struct` test suite) for setup/teardown — no shared mutable state.

```swift
import Testing
@testable import Venn

struct SanitizeTests {
    @Test func handleRejectsTooShort() {
        #expect(Sanitize.handle("ab") == .invalid(.tooShort))
    }

    @Test func handleAcceptsThreeChars() {
        #expect(Sanitize.handle("ada") == .valid("ada"))
    }
}
```

### Coverage gate

CI fails the Tests job if repo-wide line coverage drops below the threshold defined in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) (currently 30%). Only line coverage is checked — function and branch coverage are too noisy at our size.

The threshold is intentionally conservative because we don't unit-test SwiftUI views (they're tested in XCUITest, which has its own coverage path). Ratchet it up as the test surface grows; treat any meaningful drop as a signal to add tests, not a signal to lower the threshold.

## Rate limiting

Every Supabase Edge Function and RPC enforces a sliding-window rate limit. The pattern (in SQL):

```sql
create or replace function rl_check(_key text, _limit int, _window interval)
returns boolean language plpgsql as $$
declare _count int;
begin
  insert into rate_limits (key, ts) values (_key, now());
  delete from rate_limits where ts < now() - _window;
  select count(*) into _count from rate_limits where key = _key;
  return _count <= _limit;
end;
$$;
```

Inside an Edge Function or RPC: call `rl_check('post_create:' || auth.uid()::text, 10, '1 minute')`. Edge Functions return HTTP 429 when it's false; RPCs `raise exception 'rate_limited' using errcode = 'P0429'` — the client maps that SQLSTATE to `AppError.rateLimited` (see `AppError.mapPostgrestError`). The canonical implementation lives in the `overlap_rpc` migration.

Client-side throttling (search debounce, disabled buttons mid-flight) is UX feedback only — the server-side check above is the real limit.

## PR review rubric

When reviewing a PR, check:

1. **Architecture:** Do views/view-models/services stay in their lanes?
2. **State:** Is the simplest tool used? Is `@State` overused?
3. **Errors:** Is anything swallowed? Is the user-facing message useful?
4. **Concurrency:** Anything `@MainActor` that shouldn't be? Anything that should be?
5. **Tests:** Did new logic land with tests? If not, why?
6. **Naming:** Do names describe behavior, not implementation?
7. **Comments:** Are they explaining _why_, not _what_?
8. **Conventional Commits:** Does the squash title follow the spec?
