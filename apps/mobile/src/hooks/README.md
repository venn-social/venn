# hooks/

Cross-feature custom React hooks. Anything that's reusable across two or more features goes here.

If a hook is only used inside one feature, it lives in that feature's folder (e.g., `src/features/auth/useAuth.ts`) — not here.

**When you add a hook here:**

- Name it `useXxx.ts` (camelCase, must start with `use`).
- Add a colocated `useXxx.test.ts` if it has logic worth testing.
- Export it directly — no barrel `index.ts` needed for individual hooks.

**Examples that would live here** (none yet):

- `useDebouncedValue` — generic debouncer.
- `useNetworkStatus` — read connectivity.
- `useAppVersion` — read app version + build number.
