# stores/

Zustand stores for state that's genuinely global (per [`docs/ARCHITECTURE.md`](../../../../docs/ARCHITECTURE.md#state-management)).

**Use this folder only when:**

- The state is truly app-wide (e.g., the current user, push notification token, a global feature flag).
- Component-local `useState` and feature-level React Context have both proven insufficient.

**Don't use this folder for:**

- Server data — that lives in feature hooks (`useFeed`, `useProfile`) which call services.
- Form state — `react-hook-form` handles that locally.

**When you add a store here:**

- Name it `xxxStore.ts` (camelCase + `Store` suffix).
- Use Zustand's standard `create()` pattern. No middleware unless there's a clear reason.
- Add a colocated `xxxStore.test.ts` for any non-trivial logic.

**Examples that would live here** (none yet):

- `sessionStore.ts` — current user, pulled from AuthProvider once and exposed globally.
- `pushTokenStore.ts` — APNs/FCM token + permission state.
