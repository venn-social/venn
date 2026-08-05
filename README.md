# Venn

[![CI](https://github.com/venn-social/venn/actions/workflows/ci.yml/badge.svg)](https://github.com/venn-social/venn/actions/workflows/ci.yml)

A social app where people log what they consume — movies, music, books, restaurants, games — in one place, and share their favorites with friends. Every profile shows a Venn diagram of where your tastes overlap with the person you're looking at. **iOS + web**, both targeting December 2026. iOS is built natively in **Swift 6 + SwiftUI** on **iOS 26+** to take advantage of Liquid Glass and other Apple-native APIs; the web app is **Next.js** in [`web/`](./web), sharing one Supabase backend.

See the [product vision](https://www.notion.so/product-vision-34bc60c854a28109939dd2d83bb135a4) in Notion for the what and the why. The rest of this README is about the how — if you're here to contribute.

> **2026-05-01:** the repo migrated from React Native + Expo to native Swift. The pre-migration codebase is preserved on the [`archive/rn-expo`](https://github.com/venn-social/venn/tree/archive/rn-expo) branch. See [ADR 0002](./docs/decisions/0002-swift-over-react-native.md) for the reasoning.

## Current app status

The three-tab app — **Feed**, **Explorer**, **Profile** — is wired to real Supabase data:

- **Auth + onboarding** — magic-link email sign-in with deep-link callback, then a stepped first-run flow: claim a username, optional avatar upload. (Plus a DEBUG-only "continue as guest" bypass for development.)
- **Feed** — an image-forward stream of posts from people you follow (plus your own), with real cover art.
- **Explorer** — browse the media catalog by category, live-search movies/TV (TMDB), books (OpenLibrary), and music (MusicBrainz + Cover Art Archive), or search **People** and open their profiles. Tapping a media result opens the composer.
- **Composer** — the log flow: pick an item → rate (Love/Like/Dislike) → optional caption → log it or add to watchlist.
- **Profile** — your profile with follow counts, edit sheet + avatar upload, and Collection / Watchlist shelves with tap-through library lists.
- **Public profiles + the Venn** — other users' profiles with follow/unfollow, follower/following lists, and the signature **"Your Venn"** taste overlap: a proportional Venn diagram with a Jaccard "NN% match" headline.

Still ahead (tracked in Notion): private accounts with follow requests (backend in review), the TestFlight release pipeline (see [`docs/RELEASE.md`](./docs/RELEASE.md), blocked on Apple Developer enrollment), and — per the [product vision](https://www.notion.so/product-vision-34bc60c854a28109939dd2d83bb135a4) — the first external-app sync and rule-based recommendations v0.

## For first-time contributors

The team works **AI-pair-first**: most code is written in conversation with Claude inside VS Code, not by hand. You don't need to be an engineer to contribute productively — you do need the toolchain installed.

**Read [`docs/SETUP.md`](./docs/SETUP.md)** top to bottom. It walks you through everything: GitHub + Notion access, Xcode, the brew toolchain, **VS Code + the Claude Code extension**, the plugin bundle (Superpowers, Figma, etc.), Notion MCP, and your first PR. Plan ~90 minutes the first time.

If you're non-technical, the fastest path is to install VS Code + Claude Code first (steps 5–6 of SETUP.md), then hand the rest of the doc to Claude: **"Open `docs/SETUP.md` and walk me through it from where I am."**

For day-to-day workflow once you're set up, read **[.github/CONTRIBUTING.md](./.github/CONTRIBUTING.md)** (branch → commit → PR → review → merge) and skim **[`CLAUDE.md`](./CLAUDE.md)** so you know what Claude already knows about the project.

## For people who already know what they're doing

Prerequisite: install **Xcode 26** from the Mac App Store first (the brew toolchain depends on it).

```bash
git clone git@github.com:venn-social/venn.git
cd venn
make setup                       # brew tools + node deps + project + SPM resolve
cp .env.example .env             # fill in real Supabase + observability values
xed ios/Venn.xcodeproj           # open in Xcode, hit ⌘R
```

- `make doctor` — health-check the env (Xcode, brew tools, `.env`, hooks). Run any time things feel off.
- `make verify` — doctor + lint + format-check + tests. Run before every PR.

If you'll be using Claude on the project, also do the [Claude Code + plugins + Notion MCP](./docs/SETUP.md#5-install-vs-code-and-the-claude-code-extension) section of SETUP.md — that's how the rest of the team works.

## How this repo is organized

```
venn/
├── ios/                          Native iOS app (frontend)
│   ├── project.yml               XcodeGen source of truth
│   ├── Venn/                     App target sources (App, Features, Components, ...)
│   ├── VennTests/                Unit + snapshot tests
│   └── VennUITests/              UI tests
├── supabase/                     Backend: SQL migrations, seed data, local config
├── scripts/                      Repo tooling (doctor, codegen, seeding, CI helpers)
├── docs/                         Architecture, workflow, coding standards, ADRs
├── .github/                      CI workflows, PR template, CODEOWNERS
└── .husky/                       Pre-commit / commit-msg / pre-push hooks
```

**New to the codebase? Start with [`docs/CODEMAP.md`](./docs/CODEMAP.md)** — a plain-language "what you see on screen → which file" guide. Every major decision behind the layout is documented in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md), and known shortcuts live in [`docs/TECH_DEBT.md`](./docs/TECH_DEBT.md).

## The rules (non-negotiable)

1. **Never push to `main` directly.** Always work on a branch, open a PR, get an approval.
2. **Every PR runs CI** (SwiftLint, SwiftFormat lint, Prettier check, XCTest). If CI fails, you can't merge.
3. **Commits follow [Conventional Commits](https://www.conventionalcommits.org/)**: `feat(feed): add pull-to-refresh`, `fix(auth): crash on empty email`.
4. **No force unwraps in production code.** No `try!`, no `as!`. See [`docs/CODING_STANDARDS.md`](./docs/CODING_STANDARDS.md).
5. **Never commit secrets.** `.env` is gitignored. Use `.env.example` as the template.

## Tech stack

| Layer         | Choice                           | Why                                                           |
| ------------- | -------------------------------- | ------------------------------------------------------------- |
| Language      | Swift 6 (strict concurrency)     | Memory-safe, fast, first-class on Apple platforms.            |
| UI            | SwiftUI on iOS 26+               | Liquid Glass, `@Observable`, structured concurrency.          |
| Project gen   | XcodeGen                         | No more `.xcodeproj` merge conflicts.                         |
| Dependencies  | Swift Package Manager            | Native, no Cocoa­Pods/Carthage layer.                         |
| Backend       | Supabase (`supabase-swift`)      | Auth, Postgres, storage, realtime — all managed.              |
| Persistence   | supabase-swift session store     | Tokens in the Keychain via the SDK; UserDefaults for prefs.   |
| Observability | Sentry-Cocoa + PostHog iOS       | Errors + product analytics.                                   |
| Testing       | Swift Testing + XCUITest         | Apple's modern test frameworks.                               |
| Lint / format | SwiftLint (strict) + SwiftFormat | Auto-fix on save, enforced in CI.                             |
| Git hooks     | Husky                            | Can't commit unformatted or broken code.                      |
| CI            | GitHub Actions on `macos-latest` | Native macOS runners with current Xcode preinstalled.         |
| AI pair       | Claude Code (VS Code extension)  | Drives most coding sessions — see [`CLAUDE.md`](./CLAUDE.md). |
| Project mgmt  | Notion HQ + Notion MCP           | Tasks, meetings, vision — Claude reads/writes via MCP.        |

## Future considerations

On the radar, deliberately not done yet:

- **`hex` MCP servers** ([levnikolaevich/claude-code-skills](https://github.com/levnikolaevich/claude-code-skills)) — `hex-graph` (SQLite code knowledge graph), `hex-line` (hash-verified editing), `hex-ssh` (remote SSH execution). The original "revisit at ~50 files / 5k lines" threshold has been crossed (~75 Swift files / ~9.5k lines as of June 2026), but plain grep + the docs are still doing fine — adopt when navigation actually starts hurting, or if anyone starts working from a cloud Mac.
- **Per-PR TestFlight builds** — Xcode Cloud or Fastlane Match. Needs an Apple Developer account first.
- **CodeQL / static analysis** — defer until we have user-facing features sensitive enough to warrant another security gate beyond the existing TruffleHog secret scan.
- **Sentry source maps + release tracking** — wire up once we cut real builds (currently relevant only for production traces, not simulator).
- **End-to-end UI tests beyond XCUITest stubs** — start once the first real social flow lands (auth → profile → first post).

## License

See [`LICENSE`](./LICENSE).
