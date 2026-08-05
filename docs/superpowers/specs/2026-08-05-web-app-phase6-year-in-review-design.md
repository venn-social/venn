# venn web app — Phase 6: Year in Review

## Context

Explorer (Phase 5, PR #142) closed the last functional dead end on web. Year in Review is the **only** iOS surface web still lacks. After this, the two platforms match.

This is the smallest phase so far, and deliberately so: both backend RPCs already exist and are already rate-limited, so there is no migration and no new backend work. It is a read-only page over data the database can already produce.

> **Branch note:** this work is stacked on `feat/web-explorer` (PR #142), which is open but not yet merged. #142 should merge first.

## Scope

- **`/profile/year`** — the personal stats page: total logged, trailing-twelve-month activity chart, per-kind breakdown.
- **A link from `/profile`**, mirroring where iOS puts it (an icon button in `ProfileView`'s top bar).

### Explicitly out of scope

Viewing anyone else's stats. Both RPCs derive the viewer from `auth.uid()` internally and can only ever return the caller's own data — showing someone else's would need new backend functions plus a privacy decision about what a private account exposes. That is a different piece of work, not a UI variation.

## Architecture

### Routing

`app/(app)/profile/year/page.tsx`. Nesting under the already-reserved `profile` segment means **no new reserved username and no migration** — a top-level `/year-in-review` would have needed both.

### Data

`lib/yearInReview.ts` wraps the two existing RPCs:

- `personal_stats_by_kind()` → `{ kind, consumed_count, saved_count, rated_count, avg_rating, top_creator, top_creator_count }` per kind.
- `personal_stats_monthly()` → `{ month, count }` for the trailing twelve months.

Both are `security invoker`, resolve the viewer from `auth.uid()`, and are rate-limited at 30/minute via `rl_check`. Nothing new is needed server-side.

`totalConsumed` is computed client-side by summing `consumedCount` across kinds, mirroring `YearInReviewSummary.totalConsumed` rather than adding a third RPC.

Both fetches run **in parallel in the Server Component**, matching how `/feed` and `/profile` already load. The stats are personal and change only when the user logs something, so there is nothing to refresh in the browser — a client-side fetch would add a spinner and a slower first paint for no benefit.

### Components

- `components/YearActivityChart.tsx` — the trailing-twelve-month bars.
- `components/YearKindCard.tsx` — one card per media kind.

**The chart uses plain CSS-sized bars, not a charting library.** This is not a web-side compromise: `YearInReviewMonthlyChart.swift` explicitly uses plain `Capsule` bars rather than Apple's Charts framework, so both platforms make the same call. Twelve proportional bars need no dependency, and adding one would raise bundle-size and hydration questions for no gain. CLAUDE.md is explicit about not introducing dependencies without a clear reason.

Bar heights are a percentage of the busiest month. When every month is zero, bars render at their minimum height rather than collapsing to nothing, so the axis still reads as a chart rather than an empty box.

**Accessibility**: iOS composes a spoken summary of the whole chart — "Monthly activity, trailing twelve months. Jan: 3, Feb: 5, …" — because twelve individually-labelled bars are useless to a screen reader. Web mirrors that exactly as an `aria-label` on the chart container, with the individual bars hidden from the accessibility tree.

### Copy

Ported verbatim from `YearInReviewView.swift`:

- Page title: **Year in Review**
- Header: the total, then **logged in the last year**
- Chart heading: **Activity**
- Empty state: **Nothing logged yet** / "Log a few things and your year in review builds up here."
- Per-kind card: the pluralized kind name ("Movies"), the consumed count, and **Most logged: {creator}** when a top creator exists.

## Error handling

The established pattern — a loading/loaded/error shape with errors mapped at one boundary.

- A failed stats query renders "Couldn't load your stats." rather than an empty page, matching iOS's `ErrorStateView(unknownTitle:)`.
- Zero logged items is the **empty state, not an error**. This matters right now: the database holds a single post, so this page will legitimately show a total of 1 and a near-flat chart. That is correct output, not a bug.
- A `P0429` from either RPC's rate limit surfaces as "Too many requests — give it a moment.", distinct from a generic failure.

## Testing

- **Unit (Vitest)**: `toKindStats`/`toMonthlyStats` row mapping including null `avg_rating` and null `top_creator` (both common — a kind with nothing rated has no average); `totalConsumed` summing; the bar-height calculation, including the all-zero case that would otherwise divide by zero.
- **Component (RTL)**: the empty state renders when nothing is logged; a populated summary renders the total, the kind cards, and the chart's accessibility summary.
- **E2E (Playwright)**: `/profile/year` redirects to `/login` when signed out.

## Open questions (not blocking)

- The page is titled "Year in Review" but shows a trailing twelve months rather than a calendar year, matching iOS. If a true calendar-year retrospective is ever wanted (the seasonal "your 2026 in review" product moment), that is a different query and a different page — worth being aware the current name implies something the data does not do.
