# Context for Claude Code

This file is read automatically when Claude Code starts in this repo. It's the "brief the agent" file — everything Claude should know before writing a single line.

---

## What this repo is

**venn** — a social app where people log what they consume (movies, music, books, restaurants, games) in one place, and share their favorites with friends. Every profile shows a Venn diagram of where your tastes overlap with the person you're viewing; that overlap primitive is the whole point. **iOS only**, TestFlight target **December 2026**.

The founding team is small and non-technical. The codebase is being treated like a professional, Meta-grade engineering project from day one. For the full product vision (MVP scope, what's in and what's out, phasing), see the [product vision](https://www.notion.so/product-vision-34bc60c854a28109939dd2d83bb135a4) page in Notion.

> **Migration note (2026-05-01):** the repo migrated from React Native + Expo to native Swift + SwiftUI to unlock Liquid Glass and other Apple-native features. The pre-migration codebase is preserved on the `archive/rn-expo` branch. ADR [`0002-swift-over-react-native.md`](./docs/decisions/0002-swift-over-react-native.md) records the reasoning.

## Tech stack (locked in)

- **Language:** Swift 6 in strict concurrency mode. `SWIFT_STRICT_CONCURRENCY=complete`, warnings treated as errors. No force unwraps in production code (SwiftLint blocks them).
- **UI:** SwiftUI on iOS 26+. The minimum deployment target is **iOS 26.0** so we can use Liquid Glass, the new `@Observable` macro, structured tasks, and other iOS 26 APIs without conditional code.
- **Project generation:** [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated from [`ios/project.yml`](./ios/project.yml) and is gitignored — no more pbxproj merge conflicts. Run `make project` after pulling.
- **Backend:** Supabase (Postgres + Auth + Storage + Realtime) via [supabase-swift](https://github.com/supabase/supabase-swift). All calls go through service wrappers in `ios/Venn/Services/*.swift` and `ios/Venn/Features/<name>/*Service.swift`. Never call `client.from(...)` from a view.
- **Dependencies:** Swift Package Manager only (declared in `ios/project.yml`). No CocoaPods, no Carthage.
- **State:** local `@State` first → `@Observable` view-models scoped to a feature → top-level `@Observable` types injected via `.environment(...)` for cross-feature state. **No Redux-style global stores.**
- **Testing:** Swift Testing (`import Testing`, `@Test`) for units; XCUITest for UI flows. Services and pure utilities are unit-tested; views are not.
- **Lint/format:** [SwiftLint](https://github.com/realm/SwiftLint) (strict mode) + [SwiftFormat](https://github.com/nicklockwood/SwiftFormat). Pre-commit hooks enforce both via Husky.
- **CI:** GitHub Actions on `macos-latest`. Lint, format check, prettier check (for docs), and tests run on every PR.

## Repo layout

```
venn/
├── ios/                                   Native iOS app
│   ├── project.yml                        XcodeGen source of truth
│   ├── Venn.xcodeproj/                    GENERATED — gitignored
│   ├── Venn/
│   │   ├── App/                           @main entry, RootView, Info.plist
│   │   ├── Features/<name>/               Self-contained feature slices.
│   │   │                                  Each contains a *Service.swift,
│   │   │                                  *ViewModel.swift, and *View.swift.
│   │   ├── Components/                    Design system: Theme.swift (tokens)
│   │   │                                  + reusable primitives (Button, Screen, ...)
│   │   ├── Services/                      AppConfig, SupabaseClientProvider,
│   │   │   └── Catalog/                   Observability; external catalog APIs
│   │   │                                  (TMDB, OpenLibrary, MusicBrainz).
│   │   ├── Models/                        Cross-feature domain types.
│   │   ├── Resources/                     Assets.xcassets, Config.xcconfig, videos.
│   │   └── Utils/                         Pure helpers.
│   ├── VennTests/                         Swift Testing suites, mirroring the
│   │                                      source tree (Features/, Services/, ...).
│   └── VennUITests/                       XCUITest UI suites.
├── supabase/migrations/                   SQL migrations (unchanged from RN era).
├── docs/                                  WORKFLOW, ARCHITECTURE, CODING_STANDARDS, …
├── .github/                               CI workflows, PR + issue templates, CODEOWNERS.
├── .husky/                                Pre-commit + commit-msg hooks.
├── .swiftlint.yml                         Lint rules.
├── .swiftformat                           Format rules.
└── Makefile                               `make help` for the menu.
```

The "why" behind this layout is in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).

## Non-negotiable rules

1. **Never push to `main`.** Always work on a branch → PR → review → squash merge.
2. **Every task starts and ends in Notion.** When a coding task begins, Claude creates or finds the corresponding task in the [venn tasks DB](https://notion.so/34ac60c854a2800ca903ef85907bec3e) with `Task type = tech` and a description of what needs to be done and why. After the PR is opened, Claude updates that task's `PR Link` field with the GitHub PR URL. Notion is the source of truth — GitHub does not need to reference Notion. Task name format: lowercase, short, action-oriented (`add auth screen`, `fix feed crash`).
3. **Commits follow [Conventional Commits](https://www.conventionalcommits.org/)**: `feat(auth): add sign-in with Apple`. Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.
4. **`make verify` must pass before any PR.** It runs SwiftLint + SwiftFormat (lint mode) + tests.
5. **Never hardcode** colors, spacing, font sizes — use tokens from `ios/Venn/Components/Theme.swift`.
6. **Never expose API keys.** All secrets are read from `.env` via `AppConfig` ([`ios/Venn/Services/AppConfig.swift`](./ios/Venn/Services/AppConfig.swift)). The build pipeline injects values from `.env` into `Info.plist` at compile time. Don't hardcode a key in source even temporarily — the trufflehog CI scan will catch you.
7. **Sanitize every user input.** Anything a user can type — usernames, display names, bios, captions, search queries, comments — goes through a validator in `ios/Venn/Utils/Sanitize.swift` before it touches a service or the UI. Postgres CHECK constraints (added per migration) are the final line of defense.
8. **Rate-limit at the API boundary.** Every Supabase Edge Function and RPC enforces a sliding-window rate limit (see SQL pattern in [`docs/CODING_STANDARDS.md`](./docs/CODING_STANDARDS.md)). Client-side throttling (search debounce, disabled buttons mid-flight) is UX feedback only — it does NOT count as security; anything on the user's device can be bypassed.
9. **Imports at the top**, alphabetised, grouped (Foundation/SwiftUI first → SPM packages → internal modules). SwiftFormat enforces.
10. **Services wrap Supabase.** Views call view-models, view-models call services, services call the Supabase client. One direction only.
11. **No force unwraps (`!`) outside tests.** Use `guard let` / `if let`. SwiftLint enforces.
12. **No `try!`, no `as!`** in production code. Handle errors explicitly.
13. **Functions small and pure where possible.** Max 80 lines per function is a SwiftLint warning. Prefer composition over giant procedures. Use value types (`struct`) over reference types (`class`) unless you genuinely need identity.
14. **Schema changes go through migrations.** Every change to the Supabase schema (new column, new table, new RLS policy, new RPC) is a SQL file in `supabase/migrations/` shipped in a PR. Never run SQL directly against production via the dashboard. See [`docs/DATABASE.md`](./docs/DATABASE.md).
15. **Frontend design goes through Figma first — no improvising.** Any net-new UI surface (screen, component, sheet, empty state, error state, or a meaningful re-skin) must be designed in Figma before code is written. The implementation PR description must include the Figma node URL. Tweaks within existing design-system tokens (already-defined spacing, color, type) don't require a new frame — but a new layout, a new component, or a fresh visual direction does. **If a Figma source doesn't exist yet, pause and design it in Figma — never "just stub something reasonable."** The reasoning lives in [`docs/decisions/0008-figma-first-frontend.md`](./docs/decisions/0008-figma-first-frontend.md).
16. **Frontend code is component-first and split by folder.** Never build large SwiftUI screens by stacking private one-off subviews in a single file. Each tab or flow lives in its own `Features/<Name>/` folder, and meaningful screen sections get their own files. Reusable UI belongs in `Components/`, feature-only UI belongs in that feature folder, and repeated layout/styling must be extracted before it is copied. If a view file is becoming hard to scan, split it immediately.

## Common commands (from repo root)

```bash
make setup                # one-time: install Homebrew tools + node deps + generate project
make project              # regenerate Venn.xcodeproj from project.yml (after pulling)
make build                # build for iOS Simulator
make test                 # run XCTest + Swift Testing suites
make lint                 # SwiftLint (strict)
make format               # SwiftFormat in place
make format-check         # SwiftFormat in lint mode (fails if anything is unformatted)
make verify               # lint + format-check + test (run before every PR)
make clean                # nuke DerivedData + generated Xcode project

# Supabase (see docs/DATABASE.md):
npm run db:new <name>     # create a new migration file
npm run db:reset          # wipe local DB, replay migrations + seed
npm run db:diff <name>    # auto-generate a migration from local-vs-migrations diff
npm run db:push           # apply pending migrations to the linked remote
```

> Open the project in Xcode with `xed ios/Venn.xcodeproj` (after `make project`).

## When asked to make a change

- Always create a new branch first: `git checkout -b feat/<what-youre-doing>`.
- Match the existing folder structure. If you're adding a feature, create `ios/Venn/Features/<Name>/` with its own `<Name>Service.swift`, `<Name>ViewModel.swift`, `<Name>View.swift`.
- For frontend work, design the file structure before coding. Create subfolders for major flows (`Features/Profile/Library/`, `Features/Explorer/Search/`) when a feature starts to grow, and keep individual SwiftUI files focused on one component or one screen section.
- Before adding a new button, card, row, avatar, stat, chip, or surface style, search `ios/Venn/Components/` and the current feature folder for an existing primitive to reuse. If two screens need the same UI shape, extract it to `Components/` instead of duplicating it.
- For any screen that fetches data, use the shared `LoadState` + `LoadErrorReason` state machine (`ios/Venn/Models/LoadState.swift`) and render errors with `ErrorStateView` — never declare a new per-feature loading/loaded/error enum. See "The standard load pattern" in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).
- Before adding Liquid Glass, haptics, press states, segmented controls, or scroll motion, reuse the shared frontend primitives in `Components/Glass/`, `Components/Controls/`, and `Components/Interaction/`.
- Avoid "prototype sprawl": debug-only or placeholder UI must be isolated behind `#if DEBUG` or clearly named `Prototype`, and it must not leak fake data into production services, models, or real view-models.
- If the change touches Supabase, add or update a service rather than calling the client inline.
- Add a unit test for any new pure function or service.
- Run `make verify` before suggesting the user commit.
- Write conventional commit messages.

## Project management (Notion)

All tasks and meetings live in the [venn Notion HQ](https://notion.so/HQ-34ac60c854a2805fa3b9cc6da0380285).

- [Tasks](https://notion.so/34ac60c854a2800ca903ef85907bec3e) — every ticket with owner, priority, status, and PR link.
- [Meetings](https://notion.so/34ac60c854a2801cb5eff8a694dba2d4) — weekly syncs and notes.
- [Product vision](https://www.notion.so/product-vision-34bc60c854a28109939dd2d83bb135a4) — current MVP scope, phasing, and what's explicitly out.

## Things to read before bigger tasks

- `docs/ARCHITECTURE.md` — layering, naming conventions, state management.
- `docs/CODING_STANDARDS.md` — anti-patterns we reject, patterns we like, PR review rubric.
- `docs/WORKFLOW.md` — detailed git/PR flow with troubleshooting.
- `docs/DATABASE.md` — migrations workflow (never edit the prod DB directly).
- `docs/OBSERVABILITY.md` — Sentry (errors) + PostHog (analytics) setup and usage.
- `docs/decisions/` — Architectural Decision Records. Read `docs/decisions/README.md` before making a load-bearing technical choice; add a new ADR when you make one yourself.

## Things NOT to do without asking

- Don't introduce new dependencies without a clear reason (binary size, security surface).
- Don't switch from XcodeGen to a hand-edited `.xcodeproj` — pbxproj merge conflicts are why we use XcodeGen.
- Don't add CocoaPods or Carthage. SPM only.
- Don't lower the iOS deployment target below 26.0 — that breaks Liquid Glass and other locked-in API choices.
- Don't add Android. We are iOS-only.
- Don't edit CI workflows, Husky hooks, SwiftLint/SwiftFormat configs, or CODEOWNERS without a heads-up — those enforce the team's guarantees.
- Don't commit to `main` or force-push to anyone's branch.

## Who's here

Project owner: [NAME] (`@cslmn`, [EMAIL]). Other co-founders will be added as GitHub collaborators and wired into `.github/CODEOWNERS` as they join.
