# Coding Standards

Most of these are enforced by SwiftLint, SwiftFormat, and the Swift compiler. The rest are enforced by reviewers. This doc exists so you know what to expect before you get a "please change this" comment on a PR.

## Anti-patterns we reject

| Pattern                                          | Why it's banned                                                         |
| ------------------------------------------------ | ----------------------------------------------------------------------- |
| Force unwraps (`!`) outside tests                | Crashes the app. Use `guard let` / `if let` / `??`.                     |
| `try!`, `as!`                                    | Same — turns a recoverable error into a crash.                          |
| `class` when `struct` would do                   | Reference semantics make state changes impossible to reason about.      |
| Implicit `self` capture in closures              | Causes retain cycles. Use `[weak self]` for long-lived closures.        |
| Empty `catch {}` blocks                          | Errors silently swallowed are the worst kind of bug.                    |
| Singletons that aren't services                  | Untestable. Inject via `.environment(...)` instead.                     |
| Stringly-typed identifiers (`"feed"`, `"posts"`) | Use enums or constants. Typos compile fine; behavior breaks at runtime. |
| Long-lived `@State` in views                     | Use a view-model. `@State` is for trivial UI state only.                |
| Reaching into other features' types              | Features are self-contained. Move the type to `Models/` if it's shared. |
| `print(...)` left in production code             | Use `Logger` (os_log) or Sentry breadcrumbs. SwiftLint flags this.      |
| Magic numbers                                    | Name them. `let maxAvatarSize: CGFloat = 96` beats `96`.                |

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

## Imports

```swift
// Foundation / SwiftUI / Apple frameworks first.
import Foundation
import SwiftUI

// Third-party SPM packages alphabetically.
import Kingfisher
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

Define a single `AppError` type that wraps anything that can fail. Map third-party errors at the boundary (in services).

```swift
enum AppError: LocalizedError, Sendable {
    case network(message: String)
    case unauthorized
    case validation(message: String)
    case unknown(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .network(let m): m
        case .unauthorized:   "Please sign in again."
        case .validation(let m): m
        case .unknown:        "Something went wrong."
        }
    }
}
```

View-models hold `var error: AppError?`. Views show it in an `.alert(...)`.

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

Inside an Edge Function or RPC: call `rl_check('post_create:' || auth.uid()::text, 10, '1 minute')` and return 429 if false.

The client-side limiter in `Utils/RateLimit.swift` is UX feedback only.

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
