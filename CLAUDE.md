# Context for Claude Code

This file is read automatically when Claude Code starts in this repo. It's the "brief the agent" file — everything Claude should know before writing a single line.

---

## What this repo is

**venn** — a social app where people log what they consume (movies, music, books, restaurants, games) in one place, and share their favorites with friends. Every profile shows a Venn diagram of where your tastes overlap with the person you're viewing; that overlap primitive is the whole point. iOS first, TestFlight target **December 2026**. React Native so the codebase is cross-platform; we just won't publish to Play Store at launch.

The founding team is small and non-technical. The codebase is being treated like a professional, Meta-grade engineering project from day one. For the full product vision (MVP scope, what's in and what's out, phasing), see the [product vision](https://www.notion.so/product-vision-34bc60c854a28109939dd2d83bb135a4) page in Notion.

## Tech stack (locked in)

- **Mobile framework:** React Native + Expo (SDK 52, new architecture enabled). One codebase ships iOS and Android. Expo Router for file-based navigation.
- **Language:** TypeScript in strict mode. `noImplicitAny`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes` all on. No `any` ever — use `unknown` and narrow.
- **Backend:** Supabase (Postgres + Auth + Storage + Realtime). All calls go through service wrappers in `src/services/*.service.ts`. Never call `supabase.from(...)` from screens or hooks.
- **State:** local `useState` first → feature-level React Context (see `features/auth/AuthProvider.tsx`) → Zustand for truly global state. **No Redux.**
- **Testing:** Jest + React Native Testing Library. Utils and services are unit-tested; screens are not.
- **Lint/format:** ESLint (strict flat config at repo root) + Prettier. Pre-commit hooks enforce both via Husky + lint-staged.
- **CI:** GitHub Actions — lint, format check, typecheck, tests, and commit-message check run on every PR.

## Repo layout

Monorepo using npm workspaces:

```
venn/
├── apps/mobile/                  React Native app
│   └── src/
│       ├── app/                  Expo Router screens. (tabs) = bottom-tab group.
│       ├── components/ui/        Design-system primitives: Button, Screen, Text.
│       ├── constants/            Theme tokens, routes.
│       ├── features/<name>/      Self-contained feature slices (auth, feed, …).
│       ├── hooks/                Cross-feature hooks.
│       ├── lib/                  Supabase client, env validation.
│       ├── services/             All backend calls. One *.service.ts per domain.
│       ├── types/                Cross-feature domain types.
│       └── utils/                Pure helpers + colocated tests.
├── packages/shared/              Types/constants/utils shared across apps.
├── docs/                         WORKFLOW, ARCHITECTURE, CODING_STANDARDS, GITHUB_SETUP, SUPABASE_SETUP.
├── .github/                      CI workflows, PR + issue templates, CODEOWNERS.
└── .husky/                       Pre-commit + commit-msg hooks.
```

The "why" behind this layout is in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).

## Non-negotiable rules

1. **Never push to `main`.** Always work on a branch → PR → review → squash merge.
2. **Every task starts and ends in Notion.** When a coding task begins, Claude creates or finds the corresponding task in the [venn tasks DB](https://notion.so/34ac60c854a2800ca903ef85907bec3e) with `Task type = tech` and a description of what needs to be done and why. After the PR is opened, Claude updates that task's `PR Link` field with the GitHub PR URL. Notion is the source of truth — GitHub does not need to reference Notion.
3. **Commits follow [Conventional Commits](https://www.conventionalcommits.org/)**: `feat(auth): add sign-in with Apple`. Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
4. **`npm run verify` must pass before any PR.** It runs lint + format + typecheck + test.
5. **Never hardcode** colors, spacing, font sizes — use tokens from `src/constants/theme.ts`.
6. **Never expose API keys.** All secrets are read from `.env` via the typed helper in [`src/lib/env.ts`](./apps/mobile/src/lib/env.ts). Don't hardcode a key in source even temporarily — the gitleaks CI scan will catch you, and any commit history is forever. The mobile app only ever sees `EXPO_PUBLIC_*` keys; anything else (service-role keys, third-party server tokens) lives only on the server. Use [`apps/mobile/.env.example`](./apps/mobile/.env.example) as your template.
7. **Sanitize every user input.** Anything a user can type — usernames, display names, bios, captions, search queries, comments — goes through a Zod schema in [`src/utils/sanitize.ts`](./apps/mobile/src/utils/sanitize.ts) before it touches a service or the UI. Don't write one-off validation in screens; extend the shared schemas. Postgres CHECK constraints (added per migration) are the final line of defense — these schemas are the first.
8. **Rate-limit at the API boundary.** Every Supabase Edge Function and RPC we add must enforce a sliding-window rate limit (see the SQL pattern in [`docs/CODING_STANDARDS.md`](./docs/CODING_STANDARDS.md#rate-limiting)). The client-side limiter in [`src/utils/rateLimit.ts`](./apps/mobile/src/utils/rateLimit.ts) is UX feedback only — it does NOT count as security; anything in JS on the user's device can be bypassed.
9. **Imports at the top**, in groups (external → internal `@/...` → `@venn/shared` → relative), alphabetized. ESLint enforces.
10. **Services wrap Supabase.** Screens call feature hooks, hooks call services, services call Supabase. One direction only.
11. **No `any`, no `==`, no `!` non-null assertions, no inline styles, no commented-out code.** ESLint enforces most of these; reviewers enforce the rest.
12. **Functions small and pure where possible.** Max 100 lines per function is a lint warning. Prefer composition over giant procedures.

## Path aliases

- `@/*` → `apps/mobile/src/*` (used only inside `apps/mobile`).
- `@venn/shared` → `packages/shared/src` (usable from any workspace).

## Common commands (from repo root)

```bash
npm install               # first-time or after pulling changes
npm run mobile            # start Expo dev server, scan QR in Expo Go app
npm run verify            # lint + format + typecheck + tests (run before every PR)
npm run lint:fix          # auto-fix lint issues
npm run format            # auto-fix formatting
```

Per-app (from `apps/mobile`): `npm run start`, `npm run lint`, `npm run typecheck`, `npm run test`.

## When asked to make a change

- Always create a new branch first: `git checkout -b feat/<what-youre-doing>`.
- Match the existing folder structure. If you're adding a feature, make `src/features/<name>/` with its own types/provider/hook/index.ts.
- If the change touches Supabase, add or update a service in `src/services/*.service.ts` rather than calling Supabase inline.
- Add a unit test for any new pure function or service.
- Run `npm run verify` before suggesting the user commit.
- Write conventional commit messages. If multiple commits, squash them or let the PR squash-merge collapse them.

## Project management (Notion)

All tasks and meetings live in the [venn Notion HQ](https://notion.so/HQ-34ac60c854a2805fa3b9cc6da0380285).

- [Tasks](https://notion.so/34ac60c854a2800ca903ef85907bec3e) — every ticket with owner, priority, status, and PR link. Properties: Task name, Status (Not started / In progress / Done), Task type (strategy / tech / branding), Priority (low / medium / high), Effort level, Due date, Assignee, Description, PR Link.
- [Meetings](https://notion.so/34ac60c854a2801cb5eff8a694dba2d4) — weekly syncs and notes.
- [Product vision](https://www.notion.so/product-vision-34bc60c854a28109939dd2d83bb135a4) — the current MVP scope, phasing, and what's explicitly out.

When opening a PR, always link the corresponding Notion task URL in the PR description.

## Things to read before bigger tasks

- `docs/ARCHITECTURE.md` — layering, naming conventions, state management.
- `docs/CODING_STANDARDS.md` — anti-patterns we reject, patterns we like, PR review rubric.
- `docs/WORKFLOW.md` — detailed git/PR flow with troubleshooting.
- `docs/GITHUB_SETUP.md` — one-time repo-admin steps (branch protection etc.).
- `docs/SUPABASE_SETUP.md` — backend provisioning + RLS policies.

## Things NOT to do without asking

- Don't introduce new dependencies without a clear reason (bundle size, security surface).
- Don't switch package managers (we use npm workspaces — no pnpm/yarn).
- Don't add Redux, MobX, or another state library.
- Don't edit CI workflows, Husky hooks, ESLint/Prettier configs, or CODEOWNERS without a heads-up — those enforce the team's guarantees.
- Don't commit to `main` or force-push to anyone's branch.

## Who's here

Project owner: [NAME] (`@cslmn`, [EMAIL]). Other co-founders will be added as GitHub collaborators and wired into `.github/CODEOWNERS` as they join.
