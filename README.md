# Venn

A social media app for iOS and Android, built the way Meta, Discord, and Shopify build mobile apps: one codebase in TypeScript + React Native, shipped to both platforms.

## For first-time contributors

Start with **[SETUP.md](./SETUP.md)** — it walks you through installing every tool you need (Node.js, Git, Expo, Xcode or Android Studio), cloning the repo, and opening your first pull request. Even if you've never written code before, that guide takes you from "empty laptop" to "app running on my phone."

Then read **[CONTRIBUTING.md](./CONTRIBUTING.md)** for the day-to-day workflow (branch → commit → PR → review → merge).

## For people who already know what they're doing

```bash
nvm use                # Node 20.11
npm install            # Install everything
cd apps/mobile && cp .env.example .env  # Add your Supabase creds
npm run mobile         # Start the dev server, scan QR on your phone
```

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

| Layer              | Choice                                   | Why                                                   |
| ------------------ | ---------------------------------------- | ----------------------------------------------------- |
| Mobile framework   | React Native + Expo                      | Meta's own stack; one codebase ships iOS + Android.   |
| Language           | TypeScript (strict mode)                 | Catches bugs at compile time, not in production.      |
| Navigation         | Expo Router (file-based)                 | Next.js-style routing for mobile.                     |
| State (server)     | Supabase JS + feature hooks              | Auth, Postgres, storage, realtime — all managed.      |
| State (client)     | Zustand (as needed)                      | Simpler than Redux. Add only when React state hurts.  |
| Testing            | Jest + React Native Testing Library      | The standard.                                         |
| Lint / format      | ESLint (strict) + Prettier               | Auto-fix on save, enforced in CI.                     |
| Git hooks          | Husky + lint-staged                      | Can't commit broken code.                             |
| CI                 | GitHub Actions                           | Free for public repos, easy to extend.                |

## License

MIT — see [`LICENSE`](./LICENSE).
