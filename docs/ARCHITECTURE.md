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
│   │   ├── MainView.swift                 Signed-in three-tab shell.
│   │   └── Info.plist                     CFBundle*, build-time .env injection.
│   ├── Features/
│   │   ├── Auth/                          Each feature is self-contained:
│   │   │   ├── AuthService.swift            (a) Service: Supabase calls.
│   │   │   ├── AuthViewModel.swift          (b) ViewModel: @Observable, owns state.
│   │   │   └── AuthView.swift               (c) View: pure SwiftUI.
│   │   ├── Feed/
│   │   │   ├── FeedView.swift               Screen composition only.
│   │   │   └── FeedRow.swift                Feature-only view pieces.
│   │   ├── Composer/                      Search → pick → rate → submit flow.
│   │   ├── Explorer/                      Browse + search the media catalog.
│   │   └── Profile/
│   │       ├── ProfileView.swift            Screen composition + routing.
│   │       ├── ProfileHeaderView.swift      Section component.
│   │       └── Library/                     Subflow when the feature grows.
│   ├── Components/                        Reusable UI primitives. No business logic.
│   │                                      Examples: Screen, buttons, ErrorStateView.
│   ├── Services/                          Cross-feature service surface.
│   │   ├── AppConfig.swift                Typed env access (Supabase URL, DSN, ...).
│   │   ├── SupabaseClientProvider.swift   The single shared client.
│   │   ├── ExternalAPI.swift              Shared HTTP fetch for catalog services.
│   │   └── Observability.swift            Sentry + PostHog bootstrap.
│   ├── Models/                            Domain types used in 2+ features.
│   │                                      Includes LoadState (the shared
│   │                                      loading/loaded/error state machine).
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
- **Screens are composition roots.** A `*View.swift` file should read like a table of contents for the screen: header, content, empty/error states, navigation. Meaningful sections and rows live in their own files once they are more than a few lines or likely to be reused.
- **Frontend folders grow downward.** If `Features/Profile/` starts gaining library, settings, edit, or detail flows, add subfolders such as `Features/Profile/Library/` or `Features/Profile/Edit/`. Do not keep adding sibling files to one flat folder until it becomes hard to navigate.
- **Reuse before creating.** Search `Components/` first for buttons, cards, rows, avatar, metric, chip, empty/loading, and surface primitives. If a component is useful to two features, move it to `Components/`. If it depends on feature-specific types, keep it in that feature folder and pass plain values into it.
- **Services don't know SwiftUI.** A service can be tested without spinning up a view. When a service grows large, it's split by domain — `AuthService`, `FeedService`, `ProfileService` — never by layer.
- **`Models/` is for shared types only.** A type used by exactly one feature lives in that feature.

---

## Frontend Composition

SwiftUI code must stay professional, navigable, and easy for future AI agents to edit safely.

Use this default shape for any meaningful feature:

```
Features/<Feature>/
├── <Feature>View.swift              Screen composition and navigation.
├── <Feature>ViewModel.swift         State, formatting, and user actions.
├── <Feature>Service.swift           I/O boundary, if the feature touches data.
├── <Feature>PrototypeView.swift     DEBUG-only design/demo surface, if needed.
├── <Section>View.swift              Header, list section, filter bar, etc.
└── <Subflow>/                       Detail screens or multi-screen flows.
```

Rules:

- Keep screen files small enough to scan. If a `body` contains multiple large `VStack` / `List` / `ScrollView` sections, extract those sections into named views.
- Prefer one primary type per file. Tiny private helpers are fine, but a reusable row/card/section should not live as a private type at the bottom of a screen file.
- Do not copy UI shapes. The second time you need a layout, extract it. The third time should never be copy/paste.
- `Components/` may not import feature models or services. It accepts plain values and closures so it stays reusable.
- Feature-only UI can depend on feature-local models and view-models, but it should still be split into files when it has a distinct responsibility.
- Prototype data must be isolated in preview/debug files or static fixtures. Do not mix fake sample content into production services or domain models.

When in doubt, make the code easier for a future contributor to find and replace. The app should feel like a set of well-named building blocks, not one-off SwiftUI sketches.

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

### The standard load pattern

Every "fetch a thing and render it" screen uses the same shared machinery — **don't re-declare it per feature**:

- The view-model exposes `typealias State = LoadState<Payload>` (`Models/LoadState.swift`) and maps caught `AppError`s with `LoadErrorReason(error)`.
- The view pattern-matches: `.loading` → `DeferredLoadingView`, `.loaded` → content (or `EmptyStateView`), `.error(reason)` → `ErrorStateView(reason:unknownTitle:retry:)`.

Flow-specific failure reasons that need their own copy and affordances (invalid email on sign-in, invalid bio on profile edit) stay in that feature's own `ErrorReason` enum — `AuthViewModel` is the reference example.

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
- `RelativeTime.swift` — "2h ago" timestamps for the feed.
- `URL+Static.swift` — compile-time-checked static URLs.

If a util grows past ~100 lines, it probably wants to be split into its own file or pulled into a service.

---

## What does NOT belong in this codebase

- **Framework abstractions for hypothetical future needs.** Don't write a "RepositoryProtocol" because someday we might swap Supabase. We won't.
- **Mocks of Supabase types in production code.** Test doubles live in `VennTests/Doubles/` (add as needed).
- **Singletons that aren't services.** `AppConfig.load()` and `SupabaseClientProvider.shared` are fine because they're configured once at launch. Don't add more.
