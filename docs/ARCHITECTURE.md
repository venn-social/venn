# Architecture

How the codebase is laid out and **why**. Read this before adding a new feature so you put files in the right place.

---

## The single most important rule

**Views call view-models. View-models call services. Services call Supabase.**

Every direction is one-way. A view never imports `Supabase`. A service never imports SwiftUI.

```
View (SwiftUI)
   ↓ binds to
ViewModel (@Observable)
   ↓ calls
Service (struct, framework-free)
   ↓ uses
SupabaseClientProvider
   ↓
supabase-swift
```

If you find yourself writing `client.from("posts")` inside a view, stop. The query belongs in a service. If a view-model needs to format a date for display, that's the view-model's job — but the data shape comes from the service.

---

## Folder layout

```
ios/
├── project.yml                            XcodeGen source of truth.
├── Venn.xcodeproj/                        GENERATED — gitignored.
├── Venn/
│   ├── App/
│   │   ├── VennApp.swift                  @main entry point. Calls Observability.bootstrap.
│   │   ├── RootView.swift                 Top-level routing decision (auth / main app).
│   │   ├── ContentView.swift              Default placeholder; replace as routing lands.
│   │   └── Info.plist                     CFBundle*, build-time .env injection.
│   ├── Features/
│   │   ├── Auth/                          Each feature is self-contained:
│   │   │   ├── AuthService.swift            (a) Service: Supabase calls.
│   │   │   ├── AuthViewModel.swift          (b) ViewModel: @Observable, owns state.
│   │   │   └── AuthView.swift               (c) View: pure SwiftUI.
│   │   ├── Feed/
│   │   └── Profile/
│   ├── Components/                        Reusable UI primitives. No business logic.
│   │                                      Examples: Screen, Button, Avatar, Card.
│   ├── Services/                          Cross-feature service surface.
│   │   ├── AppConfig.swift                Typed env access (Supabase URL, DSN, ...).
│   │   ├── SupabaseClientProvider.swift   The single shared client.
│   │   └── Observability.swift            Sentry + PostHog bootstrap.
│   ├── Models/                            Domain types used in 2+ features.
│   ├── Resources/
│   │   ├── Assets.xcassets                Images, colors, app icon.
│   │   └── Config.xcconfig                Build settings (.env values flow here).
│   └── Utils/                             Pure helpers. Easiest things to test.
├── VennTests/                             Swift Testing unit suites.
└── VennUITests/                           XCUITest suites.
```

### Why this shape

- **Features are self-contained.** Adding "Notifications" means adding a single folder. Removing it means deleting a folder. No grepping for "is anything outside this feature using `NotificationsViewModel`?"
- **Components are dumb.** Anything in `Components/` can be dropped into a different app with no work. If a component reaches into a feature's types, that's a smell.
- **Services don't know SwiftUI.** A service can be tested without spinning up a view. When a service grows large, it's split by domain — `AuthService`, `FeedService`, `ProfileService` — never by layer.
- **`Models/` is for shared types only.** A type used by exactly one feature lives in that feature.

---

## State management

Use the simplest tool that works:

| Need                                          | Use this                                                   |
| --------------------------------------------- | ---------------------------------------------------------- |
| Local UI state (a toggle, a text field)       | `@State`                                                   |
| Multi-property state in a screen              | `@Observable` view-model, `@State` reference               |
| State shared across a feature's screens       | `@Observable` view-model, injected via `.environment(...)` |
| State shared across the whole app (auth, ...) | `@Observable` type at app root, injected at the scene      |

We don't have a Redux. We don't have TCA. If a feature genuinely needs centralized state, prefer a feature-scoped `@Observable` view-model. Adopt The Composable Architecture only if a future product surface (live overlap recompute, multi-step flows, undo) demands it — and then in an ADR.

### Why `@Observable` over `ObservableObject`

`@Observable` (Swift 5.9+) is opt-in tracking — SwiftUI re-renders only views that read a property that actually changed. `ObservableObject` re-renders on any `@Published` write. We're locked to iOS 26 so `@Observable` is universally available.

---

## Data flow

### Reading data

```
View
  → reads from ViewModel
ViewModel
  → calls Service.fetchSomething()
  → assigns the result to its own @Observable property
Service
  → SupabaseClientProvider.client.from("table").select(...)
```

The view is dumb: it shows `viewModel.posts`. The view-model holds state. The service does I/O.

### Writing data

```
View → button tap → ViewModel.submit()
ViewModel
  → validates via Utils/Sanitize
  → optimistically updates local state
  → calls Service.create(...)
  → on failure: roll back, surface error
```

Optimistic updates are the default for anything that should feel instant (likes, follows). For destructive or expensive operations (post creation, profile changes), wait for the round-trip and show a spinner.

---

## Concurrency

- All view-model methods are `@MainActor`. SwiftUI bindings expect main-thread mutations.
- Services are `Sendable` value types when possible. Pass them across actor boundaries freely.
- Use `async/await` everywhere. No callback APIs in new code.
- `Task { ... }` is fine inside a view for fire-and-forget. For anything cancellable, hold the `Task` on the view-model.

`SWIFT_STRICT_CONCURRENCY=complete` is enabled, so the compiler enforces this. If something doesn't compile because of an actor isolation error, the answer is "make it `Sendable` or hop to the right actor" — not silence the warning.

---

## Naming conventions

- **Types:** `UpperCamelCase` (`FeedView`, `PostDTO`, `AuthError`).
- **Methods, vars:** `lowerCamelCase` (`fetchRecentPosts`, `currentUser`).
- **Files:** match the primary type they declare (`FeedView.swift` declares `FeedView`).
- **Tests:** `<TypeUnderTest>Tests.swift` with `@Test func <behavior>()`.
- **Service methods are verbs:** `fetchRecentPosts`, `createPost`, `signOut`. They describe what happens, not what's returned.
- **DTOs end in `DTO`** (`PostDTO`) when they're the wire-shape from Supabase. Domain types don't carry the suffix.

---

## What goes in `Utils/`

Anything **pure, deterministic, and dependency-free**. No SwiftUI. No Foundation imports beyond what's strictly needed. Easy to unit-test. Examples:

- `Sanitize.swift` — validation/normalisation of user input.
- `RateLimit.swift` — UX-level client-side throttle (the _real_ rate limit lives in Postgres).
- `Formatters.swift` — date / number formatting for display.
- `Result+Extensions.swift` — small ergonomic helpers.

If a util grows past ~100 lines, it probably wants to be split into its own file or pulled into a service.

---

## What does NOT belong in this codebase

- **Framework abstractions for hypothetical future needs.** Don't write a "RepositoryProtocol" because someday we might swap Supabase. We won't.
- **Mocks of Supabase types in production code.** Test doubles live in `VennTests/Doubles/` (add as needed).
- **Singletons that aren't services.** `AppConfig.load()` and `SupabaseClientProvider.shared` are fine because they're configured once at launch. Don't add more.
