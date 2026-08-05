# Web App Phase 6: Year in Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the personal stats page — the last iOS surface web lacks. After this, the two platforms match.

**Architecture:** A Server Component fetches both existing RPCs in parallel. The chart is plain CSS-sized bars, matching iOS's deliberate choice of `Capsule` over the Charts framework. No migration and no backend work — both RPCs exist and are already rate-limited.

**Tech Stack:** Next.js 16 (App Router), `@supabase/supabase-js`, Tailwind v4, Vitest, React Testing Library, Playwright.

## Global Constraints

- Node 24 (`.nvmrc`) — run `nvm use` in `web/` before any command.
- Design tokens only: the `--color-*` vars in `app/globals.css` and Tailwind's numeric spacing scale. **Never** add a named `--spacing-*` key.
- Copy mirrors `YearInReviewView.swift` / `YearInReviewKindCard.swift` / `YearInReviewMonthlyChart.swift` verbatim.
- **No charting library.** iOS uses plain `Capsule` bars rather than Apple's Charts framework; web matches with CSS-sized divs. Adding a dependency here would need a reason CLAUDE.md doesn't grant.
- **No migration** — `personal_stats_by_kind()` and `personal_stats_monthly()` already exist, are `security invoker`, resolve the viewer from `auth.uid()`, and are rate-limited at 30/min.
- Format markdown with the lockfile-pinned prettier (`npx prettier@3.9.6`), never the local binary.
- All work stays on branch `feat/web-year-in-review`.

## File Structure

| File                                   | Responsibility                                |
| -------------------------------------- | --------------------------------------------- |
| `web/lib/yearInReview.ts`              | RPC wrappers, row mapping, totals, bar ratios |
| `web/components/YearActivityChart.tsx` | Trailing-12-month bars + a11y summary         |
| `web/components/YearKindCard.tsx`      | One per-kind row                              |
| `web/app/(app)/profile/year/page.tsx`  | Auth-gated route, parallel fetch              |
| `web/app/(app)/profile/page.tsx`       | Gains the link                                |

---

### Task 1: `lib/yearInReview.ts`

**Files:**

- Create: `web/lib/yearInReview.ts`
- Test: `web/lib/__tests__/yearInReview.test.ts`

**Interfaces:**

- Consumes: `MediaKind`, `MEDIA_KINDS` from `@/lib/media`.
- Produces: `interface KindStats { kind, consumedCount, savedCount, ratedCount, avgRating, topCreator, topCreatorCount }`; `interface MonthlyStat { month: string; count: number }`; `toKindStats(rows: unknown): KindStats[]`; `toMonthlyStats(rows: unknown): MonthlyStat[]`; `totalConsumed(kinds: KindStats[]): number`; `barRatio(count: number, max: number): number`; `monthLabel(month: string): string`; `fetchYearInReview(client): Promise<{ kinds: KindStats[]; monthly: MonthlyStat[] }>`.

Ports `YearInReviewService.swift`'s `KindStats`/`MonthlyStat`/`YearInReviewSummary`.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/yearInReview.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  barRatio,
  monthLabel,
  toKindStats,
  toMonthlyStats,
  totalConsumed
} from "@/lib/yearInReview";

describe("toKindStats", () => {
  it("maps a complete row", () => {
    const [stats] = toKindStats([
      {
        kind: "movie",
        consumed_count: 12,
        saved_count: 3,
        rated_count: 8,
        avg_rating: 4.25,
        top_creator: "Denis Villeneuve",
        top_creator_count: 3
      }
    ]);

    expect(stats.kind).toBe("movie");
    expect(stats.consumedCount).toBe(12);
    expect(stats.savedCount).toBe(3);
    expect(stats.ratedCount).toBe(8);
    expect(stats.avgRating).toBe(4.25);
    expect(stats.topCreator).toBe("Denis Villeneuve");
  });

  it("handles a kind with nothing rated and no top creator", () => {
    // Both are null constantly — a kind you've logged but never rated has
    // no average, and music often has no single dominant creator.
    const [stats] = toKindStats([
      {
        kind: "book",
        consumed_count: 2,
        saved_count: 0,
        rated_count: 0,
        avg_rating: null,
        top_creator: null,
        top_creator_count: null
      }
    ]);

    expect(stats.avgRating).toBeNull();
    expect(stats.topCreator).toBeNull();
  });

  it("drops rows with an unknown kind", () => {
    const stats = toKindStats([
      { kind: "hologram", consumed_count: 1 },
      { kind: "album", consumed_count: 2 }
    ]);
    expect(stats.map((row) => row.kind)).toEqual(["album"]);
  });

  it("returns an empty array for null or a non-array", () => {
    expect(toKindStats(null)).toEqual([]);
    expect(toKindStats({})).toEqual([]);
  });
});

describe("toMonthlyStats", () => {
  it("keeps the month string and count", () => {
    const [point] = toMonthlyStats([{ month: "2026-08-01", count: 5 }]);
    expect(point.month).toBe("2026-08-01");
    expect(point.count).toBe(5);
  });

  it("treats a missing count as zero rather than dropping the month", () => {
    // A gap in the axis would misrepresent the year; a zero bar is honest.
    const [point] = toMonthlyStats([{ month: "2026-07-01" }]);
    expect(point.count).toBe(0);
  });

  it("returns an empty array for null", () => {
    expect(toMonthlyStats(null)).toEqual([]);
  });
});

describe("totalConsumed", () => {
  it("sums consumed counts across kinds", () => {
    expect(
      totalConsumed([
        { kind: "movie", consumedCount: 12 },
        { kind: "book", consumedCount: 5 }
      ] as never)
    ).toBe(17);
  });

  it("is zero for no kinds", () => {
    expect(totalConsumed([])).toBe(0);
  });
});

describe("barRatio", () => {
  it("scales a count against the busiest month", () => {
    expect(barRatio(5, 10)).toBe(0.5);
    expect(barRatio(10, 10)).toBe(1);
  });

  it("returns zero when nothing was logged all year", () => {
    // Guards the divide-by-zero that an all-empty year would otherwise hit.
    expect(barRatio(0, 0)).toBe(0);
  });

  it("returns zero for an empty month", () => {
    expect(barRatio(0, 8)).toBe(0);
  });
});

describe("monthLabel", () => {
  it("renders a short month name", () => {
    expect(monthLabel("2026-08-01")).toBe("Aug");
  });

  it("passes through an unparseable value rather than throwing", () => {
    expect(monthLabel("not-a-date")).toBe("not-a-date");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- yearInReview`
Expected: FAIL — `Cannot find module '@/lib/yearInReview'`.

- [ ] **Step 3: Write the implementation**

Create `web/lib/yearInReview.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { MEDIA_KINDS, type MediaKind } from "@/lib/media";

/** Mirrors KindStats in YearInReviewService.swift. */
export interface KindStats {
  kind: MediaKind;
  consumedCount: number;
  savedCount: number;
  ratedCount: number;
  /** Null when nothing of this kind has been rated. */
  avgRating: number | null;
  topCreator: string | null;
  topCreatorCount: number | null;
}

/** Mirrors MonthlyStat. `month` stays the raw "YYYY-MM-DD" the RPC returns. */
export interface MonthlyStat {
  month: string;
  count: number;
}

interface KindStatsRow {
  kind?: string;
  consumed_count?: number;
  saved_count?: number;
  rated_count?: number;
  avg_rating?: number | string | null;
  top_creator?: string | null;
  top_creator_count?: number | null;
}

export function toKindStats(rows: unknown): KindStats[] {
  if (!Array.isArray(rows)) return [];

  return (rows as KindStatsRow[])
    .filter((row): row is KindStatsRow & { kind: string } =>
      Boolean(row.kind && MEDIA_KINDS.includes(row.kind))
    )
    .map((row) => ({
      kind: row.kind as MediaKind,
      consumedCount: row.consumed_count ?? 0,
      savedCount: row.saved_count ?? 0,
      ratedCount: row.rated_count ?? 0,
      // Postgres numeric arrives as a string over PostgREST.
      avgRating:
        row.avg_rating === null || row.avg_rating === undefined ? null : Number(row.avg_rating),
      topCreator: row.top_creator ?? null,
      topCreatorCount: row.top_creator_count ?? null
    }));
}

export function toMonthlyStats(rows: unknown): MonthlyStat[] {
  if (!Array.isArray(rows)) return [];
  return (
    (rows as { month?: string; count?: number }[])
      .filter((row): row is { month: string; count?: number } => Boolean(row.month))
      // A missing count is a zero month, not a month to drop — a gap in the
      // axis would misrepresent the year.
      .map((row) => ({ month: row.month, count: row.count ?? 0 }))
  );
}

/** Mirrors YearInReviewSummary.totalConsumed. */
export function totalConsumed(kinds: KindStats[]): number {
  return kinds.reduce((sum, kind) => sum + kind.consumedCount, 0);
}

/**
 * Bar height as a fraction of the busiest month. Zero when nothing was
 * logged all year, which is also what guards the divide by zero.
 */
export function barRatio(count: number, max: number): number {
  if (max <= 0) return 0;
  return count / max;
}

/** "2026-08-01" → "Aug". Returns the input unchanged if it won't parse. */
export function monthLabel(month: string): string {
  const date = new Date(`${month}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return month;
  return date.toLocaleString("en-US", { month: "short", timeZone: "UTC" });
}

/**
 * Both stats RPCs, in parallel. Each resolves the viewer from auth.uid()
 * internally, so there is no user argument — and no way to ask for someone
 * else's stats.
 */
export async function fetchYearInReview(
  client: SupabaseClient
): Promise<{ kinds: KindStats[]; monthly: MonthlyStat[] }> {
  const [byKind, monthly] = await Promise.all([
    client.rpc("personal_stats_by_kind"),
    client.rpc("personal_stats_monthly")
  ]);

  if (byKind.error) throw byKind.error;
  if (monthly.error) throw monthly.error;

  return { kinds: toKindStats(byKind.data), monthly: toMonthlyStats(monthly.data) };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- yearInReview`
Expected: PASS — 14 tests green.

- [ ] **Step 5: Commit**

```bash
git add web/lib/yearInReview.ts web/lib/__tests__/yearInReview.test.ts
git commit -m "feat(web): add the Year in Review data layer"
```

---

### Task 2: The chart and the kind card

**Files:**

- Create: `web/components/YearActivityChart.tsx`, `web/components/YearKindCard.tsx`
- Test: `web/components/__tests__/YearActivityChart.test.tsx`

**Interfaces:**

- Consumes: `MonthlyStat`, `KindStats`, `barRatio`, `monthLabel` from `@/lib/yearInReview`.
- Produces: `<YearActivityChart monthly={MonthlyStat[]} />`; `<YearKindCard stats={KindStats} />`.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/YearActivityChart.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { YearActivityChart } from "@/components/YearActivityChart";

const monthly = [
  { month: "2026-07-01", count: 2 },
  { month: "2026-08-01", count: 4 }
];

describe("YearActivityChart", () => {
  it("labels each month", () => {
    render(<YearActivityChart monthly={monthly} />);
    expect(screen.getByText("Jul")).toBeDefined();
    expect(screen.getByText("Aug")).toBeDefined();
  });

  it("summarises the whole chart for screen readers", () => {
    // Twelve individually-labelled bars are useless spoken aloud, so iOS
    // composes one summary and hides the bars. Web mirrors that.
    render(<YearActivityChart monthly={monthly} />);
    const chart = screen.getByLabelText(/Monthly activity, trailing twelve months/);
    expect(chart.getAttribute("aria-label")).toContain("Jul: 2");
    expect(chart.getAttribute("aria-label")).toContain("Aug: 4");
  });

  it("renders without dividing by zero when nothing was logged", () => {
    render(<YearActivityChart monthly={[{ month: "2026-08-01", count: 0 }]} />);
    expect(screen.getByText("Aug")).toBeDefined();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- YearActivityChart`
Expected: FAIL — cannot find `@/components/YearActivityChart`.

- [ ] **Step 3: Write the chart**

Create `web/components/YearActivityChart.tsx`:

```tsx
import { barRatio, monthLabel, type MonthlyStat } from "@/lib/yearInReview";

const CHART_HEIGHT = 120;
/** Empty months still show a sliver, so the axis reads as a chart. */
const MIN_BAR_HEIGHT = 4;

/**
 * Trailing-twelve-month activity. Plain CSS bars, not a charting library —
 * the same call YearInReviewMonthlyChart.swift makes with Capsule over
 * Apple's Charts framework.
 */
export function YearActivityChart({ monthly }: { monthly: MonthlyStat[] }) {
  const max = Math.max(0, ...monthly.map((point) => point.count));
  const summary = monthly.map((point) => `${monthLabel(point.month)}: ${point.count}`).join(", ");

  return (
    <section className="flex flex-col gap-2">
      <h2 className="text-xs font-semibold tracking-wide text-(--color-text-secondary) uppercase">
        Activity
      </h2>

      <div
        // One spoken summary, bars hidden — twelve separate labels are
        // noise to a screen reader.
        aria-label={`Monthly activity, trailing twelve months. ${summary}.`}
        className="flex items-end gap-1"
        style={{ height: CHART_HEIGHT }}
      >
        {monthly.map((point) => {
          const ratio = barRatio(point.count, max);
          return (
            <div key={point.month} className="flex flex-1 flex-col items-center gap-1">
              <div
                aria-hidden="true"
                className={
                  ratio > 0
                    ? "w-full rounded-pill bg-(--color-accent)"
                    : "w-full rounded-pill bg-(--color-surface-strong)"
                }
                style={{ height: Math.max(MIN_BAR_HEIGHT, ratio * (CHART_HEIGHT - 20)) }}
              />
              <span className="text-[10px] text-(--color-text-secondary)">
                {monthLabel(point.month)}
              </span>
            </div>
          );
        })}
      </div>
    </section>
  );
}
```

- [ ] **Step 4: Write the kind card**

Create `web/components/YearKindCard.tsx`:

```tsx
import type { KindStats } from "@/lib/yearInReview";

const PLURAL: Record<KindStats["kind"], string> = {
  movie: "Movies",
  show: "Shows",
  book: "Books",
  album: "Albums"
};

/** One media kind's totals. Ports YearInReviewKindCard.swift. */
export function YearKindCard({ stats }: { stats: KindStats }) {
  return (
    <div className="flex items-center gap-3 rounded-md bg-(--color-surface) p-4">
      <div className="flex flex-col gap-0.5">
        <p className="font-semibold text-(--color-text-primary)">{PLURAL[stats.kind]}</p>
        {stats.topCreator && (
          <p className="truncate text-sm text-(--color-text-secondary)">
            Most logged: {stats.topCreator}
          </p>
        )}
      </div>

      <div className="ml-auto flex flex-col items-end gap-0.5">
        <p className="text-xl font-semibold tabular-nums text-(--color-text-primary)">
          {stats.consumedCount}
        </p>
        {stats.avgRating !== null && (
          <p className="text-sm font-semibold text-(--color-text-primary)">
            <span className="text-(--color-accent)">★</span> {stats.avgRating.toFixed(1)}
          </p>
        )}
      </div>
    </div>
  );
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd web && npm run test -- YearActivityChart`
Expected: PASS — 3 tests green.

- [ ] **Step 6: Commit**

```bash
git add web/components/YearActivityChart.tsx web/components/YearKindCard.tsx web/components/__tests__/YearActivityChart.test.tsx
git commit -m "feat(web): add the Year in Review chart and kind cards"
```

---

### Task 3: The page and the profile link

**Files:**

- Create: `web/app/(app)/profile/year/page.tsx`
- Modify: `web/app/(app)/profile/page.tsx`
- Test: `web/e2e/year.spec.ts`

**Interfaces:**

- Consumes: `fetchYearInReview`, `totalConsumed`; `YearActivityChart`, `YearKindCard`.
- Produces: the `/profile/year` route.

**Copy** from `YearInReviewView.swift`: title **Year in Review**; the total then **logged in the last year**; empty state **Nothing logged yet** / "Log a few things and your year in review builds up here."; error **Couldn't load your stats.**

- [ ] **Step 1: Write the page**

Create `web/app/(app)/profile/year/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { YearActivityChart } from "@/components/YearActivityChart";
import { YearKindCard } from "@/components/YearKindCard";
import { createClient } from "@/lib/supabase/server";
import { fetchYearInReview, totalConsumed } from "@/lib/yearInReview";

export default async function YearInReviewPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  let summary;
  try {
    summary = await fetchYearInReview(supabase);
  } catch (error) {
    const rateLimited = (error as { code?: string } | null)?.code === "P0429";
    return (
      <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
        <h1 className="text-xl font-semibold text-(--color-text-primary)">Year in Review</h1>
        <p className="text-(--color-text-secondary)">
          {rateLimited ? "Too many requests — give it a moment." : "Couldn't load your stats."}
        </p>
      </main>
    );
  }

  const total = totalConsumed(summary.kinds);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-6 px-4 py-8">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Year in Review</h1>

      {total === 0 ? (
        <div className="flex flex-col gap-1 py-8 text-center">
          <p className="font-semibold text-(--color-text-primary)">Nothing logged yet</p>
          <p className="text-(--color-text-secondary)">
            Log a few things and your year in review builds up here.
          </p>
        </div>
      ) : (
        <>
          <div className="flex flex-col gap-0.5">
            <p className="text-4xl font-semibold tabular-nums text-(--color-text-primary)">
              {total}
            </p>
            <p className="text-(--color-text-secondary)">logged in the last year</p>
          </div>

          {summary.monthly.length > 0 && <YearActivityChart monthly={summary.monthly} />}

          <div className="flex flex-col gap-2">
            {summary.kinds.map((stats) => (
              <YearKindCard key={stats.kind} stats={stats} />
            ))}
          </div>
        </>
      )}
    </main>
  );
}
```

- [ ] **Step 2: Link it from the profile**

In `web/app/(app)/profile/page.tsx`, add a third pill to the existing Edit profile / Settings row, immediately after the Settings `<Link>`:

```tsx
<Link
  href="/profile/year"
  className="rounded-pill border border-(--color-separator) px-4 py-1.5 text-sm font-semibold text-(--color-text-primary)"
>
  Year in Review
</Link>
```

- [ ] **Step 3: Write the E2E test**

Create `web/e2e/year.spec.ts`:

```ts
import { expect, test } from "@playwright/test";

test("visiting /profile/year while signed out redirects to /login", async ({ page }) => {
  await page.goto("/profile/year");
  await expect(page).toHaveURL(/\/login/);
});
```

- [ ] **Step 4: Verify everything**

Run: `cd web && npm run lint && npm run test && npm run build && npm run test:e2e`
Expected: all pass; the build lists `/profile/year`.

- [ ] **Step 5: Commit**

```bash
git add web/app web/e2e/year.spec.ts
git commit -m "feat(web): add the Year in Review page"
```

---

### Task 4: Documentation

**Files:**

- Modify: `docs/TECH_DEBT.md`, `CLAUDE.md`, `README.md`

- [ ] **Step 1: Add the Figma backlog entry**

Under the Figma backlog list in `docs/TECH_DEBT.md`, add:

```markdown
- Web `/profile/year` — Year in Review: total-logged header, trailing-12-month bar chart, per-kind cards, and the empty state
```

- [ ] **Step 2: Record the naming mismatch**

Append a row to the tech-debt table:

```markdown
| 19 | Both platforms' "Year in Review" shows a **trailing twelve months**, not a calendar year — the name implies a retrospective the data doesn't produce. | `personal_stats_monthly()` returns the trailing twelve months, and iOS's screen was built on it. Nobody has needed a calendar-year view yet. | If a seasonal "your 2026 in review" moment is ever wanted, that's a different query and a different page — rename this one or add that one, don't overload it. |
```

- [ ] **Step 3: Update the two docs that still describe web as incomplete**

In `CLAUDE.md`, the web bullet under "Tech stack" says Phase 1 is in progress. Replace its parenthetical with:

```markdown
- **Web:** Next.js (App Router, TypeScript) in `web/`, against the _same_ Supabase project as iOS — no second backend. Tailwind, styled from tokens mirroring `Theme.swift`. Vitest + React Testing Library for units, Playwright for E2E. As of 2026-08-05 web has feature parity with iOS: auth, onboarding, feed, navigation, profiles with shelves, editing, settings, follow lists, the Venn overlap, the composer, Explorer, and Year in Review.
```

In `README.md`, the summary line says **iOS only**. Replace that sentence with:

```markdown
A social app where people log what they consume — movies, music, books, restaurants, games — in one place, and share their favorites with friends. Every profile shows a Venn diagram of where your tastes overlap with the person you're looking at. **iOS + web**, both targeting December 2026. iOS is built natively in **Swift 6 + SwiftUI** on **iOS 26+**; the web app is **Next.js** in [`web/`](./web), sharing one Supabase backend.
```

- [ ] **Step 4: Format and commit**

```bash
npx --yes prettier@3.9.6 --write docs/TECH_DEBT.md CLAUDE.md README.md
git add docs/TECH_DEBT.md CLAUDE.md README.md
git commit -m "docs: record web/iOS parity and the Year in Review naming mismatch"
```

---

## Self-Review

**Spec coverage.** `/profile/year` route → Task 3. Both RPCs in parallel → Task 1. Total logged → Task 1. Monthly chart with CSS bars and the a11y summary → Task 2. Per-kind cards → Task 2. Profile link → Task 3. Empty state, error state, rate-limit copy → Task 3. Naming mismatch → Task 4. Testing → Tasks 1, 2, 3.

**Known gaps, deliberate.** `fetchYearInReview`'s network path isn't tested directly, matching every other `lib/` fetcher; the mapping and math it depends on are covered. Signed-in rendering is component-tested rather than end-to-end (tech-debt row 13).

**Type consistency.** `KindStats`, `MonthlyStat`, `barRatio`, `monthLabel`, `totalConsumed`, `fetchYearInReview` are defined in Task 1 and used with identical names in Tasks 2 and 3. `MEDIA_KINDS` is imported from `@/lib/media`, where Phase 3 defined it. `PLURAL` in `YearKindCard` covers exactly the four `MediaKind` values.
