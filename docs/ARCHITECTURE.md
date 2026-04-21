# Architecture

This doc explains _why_ the code is shaped the way it is. The short version: we've organized it the way well-run engineering teams organize their code, because the habits pay off as the team grows.

## The layering

```
┌─────────────────────────────────────────────────────────────────┐
│  UI screens  (src/app/*)                                        │
│  ─ Thin. Render state, handle user input, call hooks.           │
│  ─ No API calls. No business logic.                             │
├─────────────────────────────────────────────────────────────────┤
│  Feature hooks  (src/features/*/useXyz.ts)                      │
│  ─ Compose services + state. Expose a clean API for screens.    │
├─────────────────────────────────────────────────────────────────┤
│  Services  (src/services/*.service.ts)                          │
│  ─ All API calls. Return typed domain objects.                  │
├─────────────────────────────────────────────────────────────────┤
│  Infra  (src/lib/*)                                             │
│  ─ Supabase client, env validation, analytics SDK.              │
└─────────────────────────────────────────────────────────────────┘
```

Layers only call downward. A screen calls a hook, a hook calls a service, a service calls infra. The infra never calls a screen. This one-way dependency graph keeps things easy to reason about and test.

## Why folders, and why _these_ folders

### `apps/mobile/src/app/` — one file per screen

We use [Expo Router](https://docs.expo.dev/router/introduction/)'s file-based routing. The file path becomes the URL.

- `src/app/(tabs)/index.tsx` → the Home tab.
- `src/app/auth/login.tsx` → `/auth/login`.
- `src/app/_layout.tsx` → wraps the whole app.
- Folders named with parens like `(tabs)` group screens without affecting the URL.

This mirrors Next.js, which most frontend engineers already know.

### `src/components/` — reusable visual pieces

- `ui/` is the design system: Button, Text, Screen. **Every screen uses these, not raw React Native primitives.** That's how we keep the look consistent.
- `feed/`, `profile/` (etc.) are domain-specific components. They can use `ui/`, but should not reach into each other.

### `src/features/<name>/` — the heart of each feature

A "feature" is a self-contained vertical slice: its own hooks, context providers, types, and any feature-specific components.

The rule: **a new teammate should be able to understand what a feature does by reading just its folder**. So if you're building "stories," all the stories code lives under `src/features/stories/` — not scattered across the whole tree.

Inside a feature folder, a typical layout is:

```
features/auth/
├── AuthProvider.tsx     Context provider
├── useAuth.ts           Hook to consume the context
├── auth.types.ts        Types local to this feature
└── index.ts             Barrel export — the feature's public API
```

Only export from `index.ts` what outside code genuinely needs. That keeps feature internals hidden.

### `src/services/` — every external call

Every single call to Supabase (or any other backend) goes through a `.service.ts` file. Never call `supabase.from('...').select(...)` from a screen or a hook — wrap it in a service function first.

Why? When we eventually need to add logging, retries, rate limiting, or replace Supabase with a different backend, it's a one-file change instead of a grep-and-replace across the whole app.

### `src/lib/` — shared infra

Things that are not features, not UI, not services: the Supabase client singleton, env validation, the analytics SDK wrapper. Small and stable.

### `src/types/` — cross-feature types

Domain types used by more than one feature. If a type is only used inside one feature, it lives in that feature's folder instead.

### `src/utils/` — pure helpers

Small pure functions with tests next to them. Examples: `formatRelativeTime`, `formatCompactCount`. No React, no state, no side effects.

### `packages/shared/` — truly cross-app code

Types, constants, and utilities that will be reused across `apps/mobile`, a future `apps/web`, and a future self-hosted backend. If it's only used by mobile, put it in `apps/mobile` instead.

## Naming conventions

- **Files**: `camelCase.ts` for pure modules, `PascalCase.tsx` for React components.
- **Folders**: `kebab-case` or `lowercase` (e.g., `src/features/auth/`, not `src/features/Auth/`).
- **Types**: `PascalCase` (`UserProfile`).
- **Interfaces over type aliases** for object shapes. Type aliases for unions.
- **Services**: `<name>.service.ts`, e.g., `auth.service.ts`.
- **Hooks**: `use<Thing>.ts`, e.g., `useAuth.ts`. Hooks must start with `use`.
- **Tests**: `<file>.test.ts` next to the file they test.

## Imports

All imports go at the top of the file, in this order (ESLint enforces this):

1. Node built-ins (rare in React Native).
2. External packages (`react`, `expo-router`, `@supabase/supabase-js`).
3. Internal modules from `@/` (app code) and `@venn/shared`.
4. Relative imports (`./`, `../`) — avoid these; use `@/` paths instead.
5. Type-only imports last.

Blank line between each group. Alphabetical within each group.

`@/` is aliased to `apps/mobile/src/`. So `import { Button } from '@/components/ui'` works from anywhere in the mobile app.

## Side effects

A file should not "do things" at import time. Modules export functions and values. Running code happens inside a function body that someone calls. The one exception: `src/lib/supabase.ts` creates the singleton client at import time — but that's one place we can audit.

## State management

In order of preference:

1. Local component state (`useState`) — 80% of the time, this is correct.
2. Feature context (see `features/auth/AuthProvider.tsx` for the pattern) — when multiple components in a feature need the same state.
3. Zustand store — when state is genuinely global (current user, push notification token).
4. Supabase realtime subscription — when the server is the source of truth and we want to stay in sync.

**Do not reach for Redux.** Zustand does the same thing with a fraction of the boilerplate.

## Testing

- `utils/*` — unit-tested. Every pure function has a test file next to it.
- `services/*` — unit-tested with the Supabase client mocked.
- `features/*` — hook tests using `@testing-library/react-native`.
- `app/*` (screens) — not unit-tested. We'd need to stub Expo Router and it's high-effort, low-return. Instead, screens are smoke-tested via end-to-end tools (later) and manually before PR merge.

We don't enforce 100% coverage. We enforce "every non-trivial pure function has a test" and "every bug fix includes a regression test."

## What this architecture is NOT

- It's not a "clean architecture" pyramid with 10 abstract layers. We have 4 layers and that's enough for a social app.
- It's not a microservices monolith. We keep everything in one monorepo until it clearly hurts.
- It's not Redux + sagas + observables. Boring tools win.

Start simple. Add structure only when the current structure breaks down.
