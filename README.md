# Venn

A social app where people log what they consume — movies, music, books, restaurants, games — in one place, and share their favorites with friends. Every profile shows a Venn diagram of where your tastes overlap with the person you're looking at. iOS first, TestFlight target December 2026. Built in TypeScript + React Native so the codebase already targets both iOS and Android; we just won't publish to Play Store at launch.

See the [product vision](https://www.notion.so/product-vision-34bc60c854a28109939dd2d83bb135a4) in Notion for the what and the why. The rest of this README is about the how — if you're here to contribute.

## For first-time contributors

Start with **[docs/SETUP.md](./docs/SETUP.md)** — it walks you through installing every tool you need (Node.js, Git, Expo, Xcode or Android Studio), cloning the repo, and opening your first pull request. Even if you've never written code before, that guide takes you from "empty laptop" to "app running on my phone."

Then read **[.github/CONTRIBUTING.md](./.github/CONTRIBUTING.md)** for the day-to-day workflow (branch → commit → PR → review → merge).

## For people who already know what they're doing

```bash
nvm use                # Node 20.11
npm run setup          # npm install + verifies your env via npm run doctor
cd apps/mobile && cp .env.example .env  # Add your Supabase creds
npm run mobile         # Start the dev server, scan QR on your phone
```

Run `npm run doctor` any time things feel off — it surfaces the silent failure modes (wrong Node, missing husky hooks, placeholder `.env`).

## How this repo is organized

```
venn/
├── apps/
│   └── mobile/         React Native + Expo app (iOS + Android)
├── packages/
│   └── shared/         Types, constants, pure utils shared across apps
├── docs/               Architecture, workflow, coding standards
├── .github/            CI workflows, PR template, CODEOWNERS
├── .husky/             Git hooks (run lint + format before every commit)
└── scripts/            One-off developer scripts
```

Every major decision behind this layout is documented in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).

## The rules (non-negotiable)

1. **Never push to `main` directly.** Always work on a branch, open a PR, get an approval.
2. **Every PR runs CI** (lint, format, typecheck, test). If CI fails, you can't merge.
3. **Commits follow [Conventional Commits](https://www.conventionalcommits.org/)**: `feat(feed): add pull-to-refresh`, `fix(auth): crash on empty email`.
4. **No `any` in TypeScript.** No commented-out code. No hard-coded colors. See [`docs/CODING_STANDARDS.md`](./docs/CODING_STANDARDS.md).
5. **Never commit secrets.** `.env` is gitignored. Use `.env.example` as the template.

## Tech stack

| Layer            | Choice                              | Why                                                  |
| ---------------- | ----------------------------------- | ---------------------------------------------------- |
| Mobile framework | React Native + Expo                 | Meta's own stack; one codebase ships iOS + Android.  |
| Language         | TypeScript (strict mode)            | Catches bugs at compile time, not in production.     |
| Navigation       | Expo Router (file-based)            | Next.js-style routing for mobile.                    |
| State (server)   | Supabase JS + feature hooks         | Auth, Postgres, storage, realtime — all managed.     |
| State (client)   | Zustand (as needed)                 | Simpler than Redux. Add only when React state hurts. |
| Testing          | Jest + React Native Testing Library | The standard.                                        |
| Lint / format    | ESLint (strict) + Prettier          | Auto-fix on save, enforced in CI.                    |
| Git hooks        | Husky + lint-staged                 | Can't commit broken code.                            |
| CI               | GitHub Actions                      | Free for public repos, easy to extend.               |

## License

MIT — see [`LICENSE`](./LICENSE).
