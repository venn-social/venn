# Venn

A social app where people log what they consume — movies, music, books, restaurants, games — in one place, and share their favorites with friends. Every profile shows a Venn diagram of where your tastes overlap with the person you're looking at. **iOS only**, TestFlight target December 2026. Built natively in **Swift 6 + SwiftUI** on **iOS 26+** to take advantage of Liquid Glass and other Apple-native APIs.

See the [product vision](https://www.notion.so/product-vision-34bc60c854a28109939dd2d83bb135a4) in Notion for the what and the why. The rest of this README is about the how — if you're here to contribute.

> **2026-05-01:** the repo migrated from React Native + Expo to native Swift. The pre-migration codebase is preserved on the [`archive/rn-expo`](https://github.com/venn-social/venn/tree/archive/rn-expo) branch. See [ADR 0002](./docs/decisions/0002-swift-over-react-native.md) for the reasoning.

## For first-time contributors

Start with **[docs/SETUP.md](./docs/SETUP.md)** — it walks you through installing every tool you need (Xcode, Homebrew, Node, the project tooling), cloning the repo, and opening your first pull request.

Then read **[.github/CONTRIBUTING.md](./.github/CONTRIBUTING.md)** for the day-to-day workflow (branch → commit → PR → review → merge).

## For people who already know what they're doing

```bash
brew install xcodegen swiftlint swiftformat xcbeautify
git clone git@github.com:venn-social/venn.git
cd venn
make setup                       # node deps + xcodegen + project generation
cp .env.example .env             # fill in real Supabase + observability values
xed ios/Venn.xcodeproj            # open in Xcode, hit ⌘R
```

`make verify` runs lint + format-check + tests. Run it before every PR.

## How this repo is organized

```
venn/
├── ios/                          Native iOS app
│   ├── project.yml               XcodeGen source of truth
│   ├── Venn/                     App target sources (App, Features, Components, ...)
│   ├── VennTests/                Unit tests
│   └── VennUITests/              UI tests
├── supabase/                     SQL migrations (backend stays unchanged)
├── docs/                         Architecture, workflow, coding standards, ADRs
├── .github/                      CI workflows, PR template, CODEOWNERS
└── .husky/                       Pre-commit + commit-msg hooks
```

Every major decision behind this layout is documented in [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md).

## The rules (non-negotiable)

1. **Never push to `main` directly.** Always work on a branch, open a PR, get an approval.
2. **Every PR runs CI** (SwiftLint, SwiftFormat lint, Prettier check, XCTest). If CI fails, you can't merge.
3. **Commits follow [Conventional Commits](https://www.conventionalcommits.org/)**: `feat(feed): add pull-to-refresh`, `fix(auth): crash on empty email`.
4. **No force unwraps in production code.** No `try!`, no `as!`. See [`docs/CODING_STANDARDS.md`](./docs/CODING_STANDARDS.md).
5. **Never commit secrets.** `.env` is gitignored. Use `.env.example` as the template.

## Tech stack

| Layer         | Choice                           | Why                                                   |
| ------------- | -------------------------------- | ----------------------------------------------------- |
| Language      | Swift 6 (strict concurrency)     | Memory-safe, fast, first-class on Apple platforms.    |
| UI            | SwiftUI on iOS 26+               | Liquid Glass, `@Observable`, structured concurrency.  |
| Project gen   | XcodeGen                         | No more `.xcodeproj` merge conflicts.                 |
| Dependencies  | Swift Package Manager            | Native, no Cocoa­Pods/Carthage layer.                 |
| Backend       | Supabase (`supabase-swift`)      | Auth, Postgres, storage, realtime — all managed.      |
| Persistence   | Keychain (`KeychainAccess`)      | Tokens; UserDefaults for non-secret prefs.            |
| Image loading | Kingfisher                       | Caching, prefetching, SwiftUI integration.            |
| Observability | Sentry-Cocoa + PostHog iOS       | Errors + product analytics.                           |
| Testing       | Swift Testing + XCUITest         | Apple's modern test frameworks.                       |
| Lint / format | SwiftLint (strict) + SwiftFormat | Auto-fix on save, enforced in CI.                     |
| Git hooks     | Husky                            | Can't commit unformatted or broken code.              |
| CI            | GitHub Actions on `macos-latest` | Native macOS runners with current Xcode preinstalled. |

## License

See [`LICENSE`](./LICENSE).
