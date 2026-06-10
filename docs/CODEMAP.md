# Code Map

A plain-language tour of the repo: **what you're looking at on screen → where the code lives.** For the _why_ behind the structure, read [`ARCHITECTURE.md`](./ARCHITECTURE.md). This file is for finding things.

## The 10-second mental model

```
You see a screen          →  ios/Venn/Features/<TabName>/
It looks a certain way    →  ios/Venn/Components/ (Theme.swift = every color/font/spacing)
It shows real data        →  the *Service.swift in that feature folder
The data lives somewhere  →  supabase/migrations/ (the database schema)
```

Everything else is plumbing.

## "I want to change…" → open this file

| I want to change…                                | Open…                                                              |
| ------------------------------------------------ | ------------------------------------------------------------------ |
| A color, font, spacing, corner radius — anywhere | `ios/Venn/Components/Theme.swift`                                  |
| The Feed tab                                     | `ios/Venn/Features/Feed/FeedView.swift`                            |
| One post row in the feed                         | `ios/Venn/Features/Feed/FeedRow.swift`                             |
| The Explorer tab (browse + search)               | `ios/Venn/Features/Explorer/ExplorerView.swift`                    |
| The log-it sheet (pick → rate → post)            | `ios/Venn/Features/Composer/ComposerSheetView.swift`               |
| The Profile tab                                  | `ios/Venn/Features/Profile/ProfileView.swift`                      |
| The sign-in screen                               | `ios/Venn/Features/Auth/AuthView.swift`                            |
| The launch video / splash                        | `ios/Venn/Components/Loading/LaunchVideoSplashView.swift`          |
| The animated gradient background                 | `ios/Venn/Components/Glass/GlassSkyBackground.swift`               |
| Which tab bar items exist                        | `ios/Venn/App/MainView.swift`                                      |
| What boots first (splash → sign-in → app)        | `ios/Venn/App/RootView.swift`                                      |
| Error / empty screens' look                      | `ios/Venn/Components/ErrorStateView.swift`, `EmptyStateView.swift` |
| A database table or security rule                | new file in `supabase/migrations/` (see `docs/DATABASE.md`)        |
| What movie/book/music search returns             | `ios/Venn/Services/Catalog/` (TMDB, OpenLibrary, MusicBrainz)      |
| App secrets / API keys                           | `.env` at the repo root (never committed)                          |

## Folder-by-folder

### `ios/Venn/` — the app, by layer

- **`App/`** — boot + routing. `VennApp` is the entry point, `RootView` decides splash vs sign-in vs app, `MainView` is the signed-in three-tab shell. `DesignPreviewView` is a DEBUG-only harness that skips auth.
- **`Features/`** — one folder per product surface (`Auth`, `Feed`, `Explorer`, `Composer`, `Profile`, plus DEBUG-only `StylePreview`). Each follows the same trio: `*View.swift` (what renders), `*ViewModel.swift` (screen state), `*Service.swift` (talks to Supabase). If you're changing what a screen _does_, you'll be in one of these folders.
- **`Components/`** — the design system. `Theme.swift` holds every color/font/spacing/radius token (the "never hardcode" rule points here). The rest are reusable UI pieces: buttons, search field, error/empty states, plus `Glass/` (Liquid Glass surfaces + scroll parallax), `Controls/`, `Interaction/` (press feel + haptics), `Loading/` (splash).
- **`Services/`** — shared infrastructure: `AppConfig` (reads `.env`), `SupabaseClientProvider` (the one DB client), `Observability` (Sentry + PostHog), and `Catalog/` (the external movie/book/music search APIs).
- **`Models/`** — the data shapes used across features (`Post`, `Media`, `UserProfile`, …) plus `LoadState` (the standard loading/loaded/error machine every screen uses) and `SupabaseSchema` (generated from the DB — don't edit by hand).
- **`Resources/`** — non-code assets: app icon, asset catalog, launch videos, localized strings, build config.
- **`Utils/`** — small pure functions (input sanitizing, relative timestamps).

### Everything outside `ios/`

- **`supabase/`** — the backend. `migrations/` is the database's entire history as SQL files; `seed.sql` is sample data; `config.toml` configures the local dev database.
- **`docs/`** — how we work: architecture, workflow, coding standards, database rules, observability, this map, the [tech-debt register](./TECH_DEBT.md), and `decisions/` (ADRs — the permanent record of every big technical choice).
- **`scripts/`** — repo tooling invoked via `make` / `npm run` (env doctor, DB type generation, seeding, CI helpers, branch pruning).
- **`.github/`** — CI pipelines, PR/issue templates, CODEOWNERS, security policy.
- **`.husky/`** — git hooks that format/lint on commit and run tests before push.
- **`CLAUDE.md`** — the brief Claude reads at the start of every session. If a rule changes, change it there.

### Tests

`ios/VennTests/` mirrors the source tree: tests for `Features/Profile/` live in `VennTests/Features/Profile/`, catalog service tests in `VennTests/Services/`, and so on. `Snapshots/` holds rendered-image baselines for visual components. `ios/VennUITests/` drives the whole app through the simulator.
