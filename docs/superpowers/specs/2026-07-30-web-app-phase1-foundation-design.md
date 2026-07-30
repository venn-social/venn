# venn web app — Phase 1: foundation (scaffold + auth + own profile)

## Context

venn has been iOS-only since the Swift/SwiftUI migration (ADR 0002). This spec adds a second platform: a public consumer website that will eventually reach full functional parity with the iOS app, launching alongside it (TestFlight target: December 2026).

This is a large, multi-subsystem project — auth, feed, composer, explorer/people search, profile (including private accounts + follow requests), the Venn overlap diagram, and Year in Review each need a web implementation. It is decomposed into sequential phases, each with its own spec and PR(s), rather than one spec covering everything. This document covers **Phase 1 only**: the foundation phase that proves the shared-backend approach end to end.

## Standing principle: cross-platform parity

Once Phase 1 lands, **iOS and web are kept in sync going forward**, not just brought to parity once and left to drift:

- Any new user-facing feature, screen, or meaningful visual change ships to both platforms together (same session/PR pair where practical). If one platform has to lag, the gap is logged explicitly in `docs/TECH_DEBT.md` rather than left implicit.
- **Design tokens** (`ios/Venn/Components/Theme.swift` on iOS, the Tailwind config on web) are treated as one conceptual source of truth, kept in lockstep by hand for now — the token set is small enough that this is tractable without a codegen pipeline. Revisit auto-generating one from the other if drift becomes a real problem.
- **Content/copy** (button labels, empty states, error messages, onboarding copy) matches across platforms unless there's a genuine platform-specific reason to differ.

This rule is also recorded in `CLAUDE.md` so it persists across sessions, not just in this spec.

## Full phase roadmap (for context — only Phase 1 is scoped in detail here)

1. **Foundation** (this doc): scaffold, magic-link auth, own profile (read-only)
2. **Public profiles + Venn overlap**: the product's signature primitive, re-implemented for web (SVG, not SwiftUI shapes)
3. **Feed**
4. **Composer**: log / rate / save
5. **Explorer / people search**
6. **Private accounts + follow requests**
7. **Year in Review**

Each phase gets its own brainstorming pass and spec before implementation — this roadmap is a planning aid, not a commitment to the later phases' detailed design.

## Phase 1 architecture

- **Framework**: Next.js (App Router, TypeScript), living in `web/` at the repo root — a sibling to `ios/`, not a separate repo. Keeps one PR history and one place to hold cross-platform context.
- **Backend**: the _same_ Supabase project iOS uses. Same tables, same RLS policies, same RPCs (`follow_counts`, `compute_overlap`, `personal_stats_by_kind`, etc.) — no backend duplication. `@supabase/supabase-js` + `@supabase/ssr` for session handling in the App Router.
- **Env**: `web/.env.local` (gitignored), sourced from the same `SUPABASE_URL` / `SUPABASE_ANON_KEY` values as iOS's `.env` — one backend, two clients.
- **Hosting**: Vercel free tier, deployed from the `web/` subdirectory. No custom domain yet — `*.vercel.app`. A custom domain is a later, purely-DNS task, not a code change.
- **Styling**: Tailwind CSS, configured with tokens mirroring `Theme.swift` (the monochrome base palette, `#0070F3` / `#4DA3FF` as the one accent, the same spacing and radius scale).
- **Tooling**: ESLint + Prettier — the web equivalent of SwiftLint/SwiftFormat's enforced rigor.

## Phase 1 scope

- Project scaffold: Next.js + Tailwind + Supabase client wiring + lint/format config.
- Magic-link sign-in: email → Supabase sends link → session established. Mirrors `AuthView`/`AuthViewModel` conceptually, as a web page — its own independent session, same underlying account as iOS (a user can be signed into both at once, same as any normal cross-platform app).
- Signed-in "my profile" page: avatar, display name, username, bio, follower/following counts. **Read-only** for Phase 1 — profile editing is a fast-follow, not blocking this phase.
- Minimal nav/header shell to hang later phases off of. Not full parity with iOS's tab bar — just enough structure.

### Explicitly out of scope for Phase 1

Feed, composer, explorer/people search, private accounts, the Venn overlap diagram, Year in Review, profile editing, custom domain. All tracked in the phase roadmap above.

## Testing

- **Unit/component**: Vitest + React Testing Library (parallel to Swift Testing).
- **E2E**: Playwright, covering the magic-link auth flow (parallel to XCUITest).
- **CI**: a new, path-filtered GitHub Actions job scoped to changes under `web/`, so web changes don't slow down iOS-only PRs and vice versa.

## Error handling

Mirrors the iOS `LoadState` / `AppError` pattern conceptually: a shared loading/loaded/error state shape for data-fetching components, and a single error-mapping boundary from Supabase JS errors to user-facing copy — not a line-by-line port, but the same _shape_ of solution, so the two codebases stay conceptually aligned even though the languages differ.

## Open questions for later phases (not blocking Phase 1)

- Whether web needs its own onboarding (username claim) flow or assumes the user already exists via iOS — likely needs its own flow for web-only signups, to be resolved when web functionality expands enough that web-first signup is realistic.
- Whether Realtime (used for anything on iOS today) needs a web equivalent — not needed for Phase 1's read-only profile.
