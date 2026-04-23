# Context for Claude Code

This file is read automatically when Claude Code starts in this repo. It's the "brief the agent" file — everything Claude should know before writing a single line.

---

## What this repo is

**venn** — a social media mobile app for iOS and Android. The founding team is small and non-technical. The codebase is being treated like a professional, Meta-grade engineering project from day one, even though we're starting from scratch.

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
2. **Every task starts and ends in Notion.** When a coding task begins, Claude creates or finds the corresponding task in the [venn tasks DB](https://notion.so/34ac60c854a2800ca903ef85907bec3e) with `Task type = Tech` and a brief description. After the PR is opened, Claude updates that task's `PR Link` field with the GitHub PR URL. Notion is the source of truth — GitHub does not need to reference Notion.
   - Task name format: lowercase, short, action-oriented — e.g. `add auth screen`, `fix feed crash`, `set up ci`. No caps, no punctuation.
   - Fill: `Task type` (tech), `Status`, `Priority`, brief `Description`. Leave `Effort level` and `Assignee` empty.
3. **Commits follow [Conventional Commits](https://www.conventionalcommits.org/)**: `feat(auth): add sign-in with Apple`. Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
4. **`npm run verify` must pass before any PR.** It runs lint + format + typecheck + test.
5. **Never hardcode** colors, spacing, font sizes — use tokens from `src/constants/theme.ts`.
6. **Never commit secrets.** `.env` is gitignored. Use `apps/mobile/.env.example` as a template.
7. **Imports at the top**, in groups (external → internal `@/...` → `@venn/shared` → relative), alphabetized. ESLint enforces.
8. **Services wrap Supabase.** Screens call feature hooks, hooks call services, services call Supabase. One direction only.
9. **No `any`, no `==`, no `!` non-null assertions, no inline styles, no commented-out code.** ESLint enforces most of these; reviewers enforce the rest.
10. **Functions small and pure where possible.** Max 100 lines per function is a lint warning. Prefer composition over giant procedures.

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

All tasks, meetings, decisions, and OKRs live in the [venn Notion HQ](https://notion.so/349c60c854a280c4b084cb76aadd19e2).

- [Tasks](https://notion.so/34ac60c854a2815db7d9cf2731c67ed4) — every ticket with owner, priority, status, and PR link
- [Projects](https://notion.so/34ac60c854a2810cae65d96103ca319c) — workstreams by phase
- [Meetings](https://notion.so/34ac60c854a281bc81d6cfc64e0707e3) — weekly syncs and notes
- [Decisions Log](https://notion.so/34ac60c854a281a19a9fd565e4c99fe3) — key decisions with rationale

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
