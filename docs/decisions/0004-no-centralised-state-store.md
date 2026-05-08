# 0004 — No centralised state store (no Redux, no TCA)

- **Status:** Proposed
- **Date:** 2026-05-08
- **Deciders:** Charles Salomon

## Context

State management is one of the load-bearing decisions in any non-trivial app. Get it wrong early and every subsequent feature pays a tax. SwiftUI ships with native primitives (`@State`, `@Observable`, `.environment(...)`) that cover most needs; the iOS community also has rich third-party options — most notably [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture) (TCA), which adopts a Redux-style unidirectional flow with explicit reducers, effects, and a single source of truth.

The pull toward TCA-style architectures is real. They give you: predictable state transitions, time-travel debugging, exhaustive testability of side effects, and a strong story for cross-feature flows (a single tap that cascades through five view-models). The cost: significant boilerplate, a learning curve that hits non-trivially when onboarding contributors, and a pattern that is hostile to "I just need a button to toggle a thing" cases that make up the bulk of UI code.

venn is iOS-only on iOS 26+ with the new `@Observable` macro available everywhere. The product surface as currently scoped (auth, profile, feed, search, post creation, follows, overlap) is feature-sliced and rarely needs cross-feature coordinated state. The founder is non-technical; the codebase needs to read like normal SwiftUI, not like a Redux dialect.

`docs/ARCHITECTURE.md` already documents the convention informally. This ADR formalises it so future contributors and Claude sessions don't propose adding Redux-shaped abstractions.

## Decision

Use SwiftUI's native state primitives. **No global store, no TCA, no Redux, no third-party state library.** Pick the simplest tool for each scope:

| Scope                                                     | Use                                                                       |
| --------------------------------------------------------- | ------------------------------------------------------------------------- |
| Local UI (a toggle, a single text field)                  | `@State`                                                                  |
| Multi-property state inside one screen                    | `@Observable` view-model held by `@State`                                 |
| State shared across a feature's screens                   | feature-scoped `@Observable` view-model, injected via `.environment(...)` |
| State shared across the whole app (auth, current session) | top-level `@Observable` injected at the scene root                        |

A new feature's default shape is: one `@Observable` view-model per screen, talking to a service. The view-model holds the screen's state machine (typically `enum State { idle, loading, success(T), error(reason) }`). State is owned where it's used; nothing leaks upward unless another feature genuinely needs it.

Cross-feature coordinated state is the exception, not the rule. If a feature needs to react to changes in another feature's state, the answer is usually one of: (a) move the shared piece up to an environment-injected `@Observable`, (b) refetch from the source of truth (Supabase) when the feature appears, (c) use `Notification` / `AsyncStream` for one-shot signals. Reach for a centralised store only if those three patterns repeatedly fail across multiple features — at which point we revisit this ADR.

## Consequences

- **Easier:** every feature reads like SwiftUI, not Redux. No reducer-action-effect dance for "show a sheet when the button is tapped." Adding a feature means adding a view-model, not registering a slice with a global store. Testing a view-model is a 10-line test, not a reducer scaffold. Onboarding a new contributor is "do you know SwiftUI?" not "do you know SwiftUI + TCA + the project's effect helpers?"
- **Harder:** complex cross-feature flows (multi-step wizards, undo/redo, optimistic updates with rollback chains) need bespoke coordination. Time-travel debugging and exhaustive effect tests are not free. We may rebuild a few small pieces of state-machinery that TCA would have given us for free.
- **Committed to:** the `@Observable` + environment-injection idiom. Adopting TCA later means rewriting every view-model in the app. Reversible, but the cost grows with surface area.

## Alternatives considered

- **The Composable Architecture (TCA).** Best-in-class for predictability and testability of complex flows. The boilerplate-to-value ratio for _our_ use cases is poor — most screens are fetch-and-render, not multi-step orchestration. The learning curve also penalises non-technical contributors and AI agents writing the code.
- **A single `@Observable` AppStore at the root.** Tempting because it's "simple." Becomes a god-object the moment more than two features depend on it; every change re-renders consumers; tests of one feature drag in the whole world.
- **Zustand-style "small store per feature, global accessors."** Doesn't have a SwiftUI-native equivalent. Could be hand-rolled but reinvents what `.environment(...)` already does idiomatically.
- **`ObservableObject` + `@Published`.** Predates `@Observable` and re-renders any consumer on any change. We're locked to iOS 26 where `@Observable`'s precise tracking is universally available — no reason to use the older mechanism.
