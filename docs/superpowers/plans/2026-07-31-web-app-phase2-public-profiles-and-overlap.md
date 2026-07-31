# Web App Phase 2: Public Profiles + Venn Overlap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the web app to parity with iOS's current profile/follow feature set: viewing another user's public profile, the full follow lifecycle (follow/unfollow/request/accept/reject) for both public and private accounts, private-account content gating, and an SVG port of the Venn taste-overlap diagram.

**Architecture:** Next.js Server Components fetch data and compute gating server-side (so a locked profile's data never reaches the browser); small Client Components handle the two genuinely interactive pieces (the follow button, the requests list). Every new data function in `lib/` is a thin wrapper over the same Supabase tables/RPCs the iOS app already calls — no backend changes in this phase. Every piece has a direct iOS reference implementation to port from.

**Tech Stack:** Next.js 16 (App Router, TypeScript), `@supabase/supabase-js`, Tailwind v4 (numeric spacing scale, named color tokens — see `app/globals.css`'s own comments on why), Vitest, Playwright.

## Global Constraints

- Node 24 (`.nvmrc`) — run `nvm use` in `web/` before any command in this plan.
- Design tokens: use the existing tokens in `app/globals.css` (`var(--color-accent)`, `var(--color-graphite)`, `var(--color-text-primary)`, `var(--color-text-secondary)`, `var(--color-surface)`, `var(--color-surface-strong)`, `var(--color-separator)`, `var(--color-on-accent)`, `var(--color-background)`). Never hardcode a hex color. Spacing/sizing uses Tailwind's native numeric scale (`gap-3`, `px-4`, etc.) — **do not** add named `--spacing-*` keys to `app/globals.css`; Tailwind v4 resolves `max-w-*`/`h-*`/etc. by checking `--spacing-*` before `--container-*`, so a named spacing key silently hijacks unrelated sizing utilities of the same name (this broke the Phase 1 login page during development — see the comment in `globals.css`).
- Copy/wording mirrors the iOS source file referenced in each task exactly, per CLAUDE.md rule 17 (cross-platform parity).
- No RPC/table/migration changes — every function in this plan calls something that already exists and that iOS already calls (`request_follow`, `respond_to_follow_request`, `follow_counts`, `compute_overlap`, the `follows` table).
- Every new Vitest test file lives under `lib/__tests__/`; every new Playwright test lives under `e2e/`. Run `npm run test` (Vitest) and `npm run build` after every task that touches `lib/` or `app/`/`components/` respectively, before committing.
- Automated tests never write real data to Supabase: E2E tests mock the follow RPC network calls (`page.route`), same approach as Phase 1's `e2e/auth.spec.ts`.

---

### Task 1: Venn diagram geometry (`lib/vennGeometry.ts`)

**Files:**

- Create: `web/lib/vennGeometry.ts`
- Test: `web/lib/__tests__/vennGeometry.test.ts`

**Interfaces:**

- Consumes: nothing (pure math, no dependencies).
- Produces: `pairGeometry(viewer: number, other: number, shared: number): PairGeometry` where `PairGeometry = { viewerRadius: number; otherRadius: number; halfDistance: number }`; `VENN_DIAGRAM_HEIGHT: number` (180); `MAX_RADIUS: number` (78); `MIN_RADIUS: number` (38).

This ports `PairGeometry` from `ios/Venn/Components/VennOverlap.swift` (lines 233-264) exactly: lobe radius is proportional to √count (relative to whichever side has more), and the distance between lobe centers shrinks as the shared fraction of the union grows.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/vennGeometry.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { MAX_RADIUS, MIN_RADIUS, pairGeometry } from "@/lib/vennGeometry";

describe("pairGeometry", () => {
  it("gives the larger side the max radius when one side is empty", () => {
    const geometry = pairGeometry(50, 0, 0);
    expect(geometry.viewerRadius).toBeCloseTo(MAX_RADIUS);
    expect(geometry.otherRadius).toBeCloseTo(MIN_RADIUS);
  });

  it("gives both sides the same radius when counts are equal", () => {
    const geometry = pairGeometry(20, 20, 5);
    expect(geometry.viewerRadius).toBeCloseTo(geometry.otherRadius);
  });

  it("moves centers closer together as the shared fraction grows", () => {
    const lowOverlap = pairGeometry(20, 20, 1);
    const highOverlap = pairGeometry(20, 20, 19);
    expect(highOverlap.halfDistance).toBeLessThan(lowOverlap.halfDistance);
  });

  it("never lets centers drift closer than 65% of the larger radius", () => {
    // shared == union (total overlap): halfDistance should hit its floor.
    const geometry = pairGeometry(20, 20, 20);
    const expectedMinHalfDistance =
      (Math.max(geometry.viewerRadius, geometry.otherRadius) * 0.65) / 2;
    expect(geometry.halfDistance).toBeCloseTo(expectedMinHalfDistance);
  });

  it("handles all-zero counts without dividing by zero", () => {
    const geometry = pairGeometry(0, 0, 0);
    expect(Number.isFinite(geometry.viewerRadius)).toBe(true);
    expect(Number.isFinite(geometry.otherRadius)).toBe(true);
    expect(Number.isFinite(geometry.halfDistance)).toBe(true);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd web && npm run test`
Expected: FAIL — `Cannot find module '@/lib/vennGeometry'`

- [ ] **Step 3: Write the implementation**

Create `web/lib/vennGeometry.ts`:

```ts
/**
 * Ports PairGeometry from ios/Venn/Components/VennOverlap.swift — same
 * two-lobe geometry, same constants. Lobe area tracks collection size
 * (radius ∝ √count); the more the two share, the closer the centers sit.
 */
export const VENN_DIAGRAM_HEIGHT = 180;
export const MAX_RADIUS = 78;
export const MIN_RADIUS = 38;

export interface PairGeometry {
  viewerRadius: number;
  otherRadius: number;
  halfDistance: number;
}

function radiusFor(count: number, maxCount: number): number {
  const ratio = Math.sqrt(Math.max(count, 0) / maxCount);
  return MIN_RADIUS + (MAX_RADIUS - MIN_RADIUS) * ratio;
}

export function pairGeometry(viewer: number, other: number, shared: number): PairGeometry {
  const maxCount = Math.max(viewer, other, 1);
  const viewerRadius = radiusFor(viewer, maxCount);
  const otherRadius = radiusFor(other, maxCount);

  const union = Math.max(viewer + other - shared, 1);
  const overlap = Math.min(Math.max(shared / union, 0), 1);
  const maxDistance = viewerRadius + otherRadius;
  const minDistance = Math.max(viewerRadius, otherRadius) * 0.65;
  const halfDistance = (maxDistance - (maxDistance - minDistance) * overlap) / 2;

  return { viewerRadius, otherRadius, halfDistance };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd web && npm run test`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Commit**

```bash
cd web
git add lib/vennGeometry.ts lib/__tests__/vennGeometry.test.ts
git commit -m "feat(web): add Venn diagram geometry, ported from VennOverlap.swift"
```

---

### Task 2: Overlap data layer (`lib/overlap.ts`)

**Files:**

- Create: `web/lib/overlap.ts`
- Test: `web/lib/__tests__/overlap.test.ts`

**Interfaces:**

- Consumes: nothing new.
- Produces: `type MediaKind = "movie" | "show" | "book" | "album"`; `interface KindOverlap { kind: MediaKind; viewerCount: number; otherCount: number; sharedCount: number }`; `interface OverlapSummary { kinds: KindOverlap[]; viewerTotal: number; otherTotal: number; sharedTotal: number }`; `summarize(kinds: KindOverlap[]): OverlapSummary`; `tasteMatchPercent(shared: number, viewer: number, other: number): number | null`; `fetchOverlap(client: SupabaseClient, otherUserId: string): Promise<OverlapSummary>`.

Ports `OverlapService.swift`, `KindOverlap`/`OverlapSummary` (`OverlapService.swift` lines 7-41), and `TasteMatch.swift`'s Jaccard percent.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/overlap.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { summarize, tasteMatchPercent, type KindOverlap } from "@/lib/overlap";

describe("summarize", () => {
  it("sums counts across kinds", () => {
    const kinds: KindOverlap[] = [
      { kind: "movie", viewerCount: 12, otherCount: 8, sharedCount: 3 },
      { kind: "book", viewerCount: 5, otherCount: 9, sharedCount: 2 },
      { kind: "album", viewerCount: 0, otherCount: 4, sharedCount: 0 }
    ];

    const summary = summarize(kinds);

    expect(summary.viewerTotal).toBe(17);
    expect(summary.otherTotal).toBe(21);
    expect(summary.sharedTotal).toBe(5);
  });

  it("sums to all zeros for an empty kinds list", () => {
    const summary = summarize([]);
    expect(summary).toEqual({ kinds: [], viewerTotal: 0, otherTotal: 0, sharedTotal: 0 });
  });
});

describe("tasteMatchPercent", () => {
  it("computes Jaccard similarity across kinds", () => {
    // viewer 17, other 21, shared 5 -> union 33 -> 5/33 ~= 15%.
    expect(tasteMatchPercent(5, 17, 21)).toBe(15);
  });

  it("returns null when there is nothing to compare", () => {
    expect(tasteMatchPercent(0, 0, 0)).toBeNull();
  });

  it("returns 100 for identical collections", () => {
    expect(tasteMatchPercent(10, 10, 10)).toBe(100);
  });

  it("returns 0 when nothing is shared", () => {
    expect(tasteMatchPercent(0, 20, 15)).toBe(0);
  });

  it("rounds to the nearest whole number", () => {
    // 1 of 3 union -> 33.33% -> 33.
    expect(tasteMatchPercent(1, 2, 2)).toBe(33);
    // 2 of 3 union -> 66.66% -> 67.
    expect(tasteMatchPercent(2, 3, 2)).toBe(67);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd web && npm run test`
Expected: FAIL — `Cannot find module '@/lib/overlap'`

- [ ] **Step 3: Write the implementation**

Create `web/lib/overlap.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Mirrors ios/Venn/Features/Profile/OverlapService.swift and
 * ios/Venn/Models/Media.swift's MediaKind.
 */
export type MediaKind = "movie" | "show" | "book" | "album";

export interface KindOverlap {
  kind: MediaKind;
  viewerCount: number;
  otherCount: number;
  sharedCount: number;
}

export interface OverlapSummary {
  kinds: KindOverlap[];
  viewerTotal: number;
  otherTotal: number;
  sharedTotal: number;
}

interface KindOverlapRow {
  kind: MediaKind;
  viewer_count: number;
  other_count: number;
  shared_count: number;
}

/** Pure aggregation — mirrors OverlapSummary's init(kinds:). */
export function summarize(kinds: KindOverlap[]): OverlapSummary {
  return {
    kinds,
    viewerTotal: kinds.reduce((sum, k) => sum + k.viewerCount, 0),
    otherTotal: kinds.reduce((sum, k) => sum + k.otherCount, 0),
    sharedTotal: kinds.reduce((sum, k) => sum + k.sharedCount, 0)
  };
}

/**
 * Jaccard similarity (|A ∩ B| / |A ∪ B|) as a 0-100 integer. Ports
 * TasteMatch.percent — null (not 0) when the union is empty, so callers
 * can distinguish "no data yet" from a real 0% match.
 */
export function tasteMatchPercent(shared: number, viewer: number, other: number): number | null {
  const union = viewer + other - shared;
  if (union <= 0) return null;
  return Math.round((shared / union) * 100);
}

/** Mirrors OverlapService.overlap(with:) — same compute_overlap RPC. */
export async function fetchOverlap(
  client: SupabaseClient,
  otherUserId: string
): Promise<OverlapSummary> {
  const { data, error } = await client.rpc("compute_overlap", { other_user: otherUserId });
  if (error) throw error;

  const kinds: KindOverlap[] = (data as KindOverlapRow[]).map((row) => ({
    kind: row.kind,
    viewerCount: row.viewer_count,
    otherCount: row.other_count,
    sharedCount: row.shared_count
  }));
  return summarize(kinds);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd web && npm run test`
Expected: PASS — all 7 tests green.

- [ ] **Step 5: Commit**

```bash
cd web
git add lib/overlap.ts lib/__tests__/overlap.test.ts
git commit -m "feat(web): add overlap data layer, ported from OverlapService.swift"
```

---

### Task 3: Follow data layer (`lib/follow.ts`)

**Files:**

- Create: `web/lib/follow.ts`
- Test: `web/lib/__tests__/follow.test.ts`

**Interfaces:**

- Consumes: `UserProfile`, `ProfileRow`, `toUserProfile` from `@/lib/profile` (Task 5's `fetchProfileByUsername` also lives in this file, but this task only needs the existing Phase 1 exports).
- Produces: `type FollowStatus = "pending" | "accepted"`; `mapFollowerRows(rows: FollowerRow[]): UserProfile[]` where `interface FollowerRow { follower: ProfileRow }`; `fetchFollowStatus(client, followerId: string, followeeId: string): Promise<FollowStatus | null>`; `requestFollow(client, targetId: string): Promise<FollowStatus>`; `unfollow(client, followerId: string, followeeId: string): Promise<void>`; `respondToRequest(client, requesterId: string, accept: boolean): Promise<void>`; `fetchPendingRequests(client, userId: string, limit?: number): Promise<UserProfile[]>`.

Ports `ios/Venn/Features/Profile/FollowService.swift` in full. Note `respond_to_follow_request`'s real signature is `(requester uuid, accept boolean)` — the RPC infers "me" (the followee) from `auth.uid()`, so there's no `followeeId` parameter to pass, same as iOS's `respondToRequest`.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/follow.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { mapFollowerRows, type FollowerRow } from "@/lib/follow";
import type { ProfileRow } from "@/lib/profile";

function makeProfileRow(username: string): ProfileRow {
  return {
    id: `${username}-id`,
    username,
    display_name: null,
    avatar_url: null,
    bio: null,
    is_private: false,
    created_at: "2026-05-01T00:00:00Z"
  };
}

describe("mapFollowerRows", () => {
  it("maps embedded follower profiles to UserProfile", () => {
    const rows: FollowerRow[] = [
      { follower: makeProfileRow("ada") },
      { follower: makeProfileRow("maya") }
    ];

    const profiles = mapFollowerRows(rows);

    expect(profiles.map((p) => p.username)).toEqual(["ada", "maya"]);
  });

  it("maps an empty row list to an empty array", () => {
    expect(mapFollowerRows([])).toEqual([]);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd web && npm run test`
Expected: FAIL — `Cannot find module '@/lib/follow'`

- [ ] **Step 3: Write the implementation**

Create `web/lib/follow.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

/**
 * Mirrors ios/Venn/Features/Profile/FollowService.swift's FollowStatus —
 * the result of asking to follow someone, per request_follow: instant for
 * a public account, pending approval for a private one.
 */
export type FollowStatus = "pending" | "accepted";

interface FollowStatusRow {
  status: string;
}

/** Mirrors FollowService.followStatus(followerID:followeeID:). */
export async function fetchFollowStatus(
  client: SupabaseClient,
  followerId: string,
  followeeId: string
): Promise<FollowStatus | null> {
  const { data, error } = await client
    .from("follows")
    .select("status")
    .eq("follower_id", followerId)
    .eq("followee_id", followeeId)
    .limit(1);

  if (error) throw error;
  const raw = (data as FollowStatusRow[])[0]?.status;
  return raw === "pending" || raw === "accepted" ? raw : null;
}

/**
 * Mirrors FollowService.requestFollow(followerID:followeeID:) — same
 * request_follow RPC. Returns the resulting status: "accepted" for a
 * public target (the edge exists immediately) or "pending" for a private
 * one (the followee must approve via respondToRequest).
 */
export async function requestFollow(
  client: SupabaseClient,
  targetId: string
): Promise<FollowStatus> {
  const { data, error } = await client.rpc("request_follow", { target: targetId });
  if (error) throw error;
  if (data !== "pending" && data !== "accepted") {
    throw new Error(`request_follow returned unexpected status: ${String(data)}`);
  }
  return data;
}

/**
 * Mirrors FollowService.unfollow(followerID:followeeID:). Deletes the
 * edge — unfollowing an accepted edge, or withdrawing/declining a
 * pending one. Idempotent: deleting a non-existent edge succeeds.
 */
export async function unfollow(
  client: SupabaseClient,
  followerId: string,
  followeeId: string
): Promise<void> {
  const { error } = await client
    .from("follows")
    .delete()
    .eq("follower_id", followerId)
    .eq("followee_id", followeeId);
  if (error) throw error;
}

/**
 * Mirrors FollowService.respondToRequest(followerID:followeeID:accept:) —
 * same respond_to_follow_request RPC. Only the followee (inferred
 * server-side from auth.uid()) may call this for their own incoming
 * requests.
 */
export async function respondToRequest(
  client: SupabaseClient,
  requesterId: string,
  accept: boolean
): Promise<void> {
  const { error } = await client.rpc("respond_to_follow_request", {
    requester: requesterId,
    accept
  });
  if (error) throw error;
}

/** One `follows` row with the follower profile embedded (internal for tests). */
export interface FollowerRow {
  follower: ProfileRow;
}

/** Pure row mapping — mirrors FollowerRow.follower in FollowService.swift. */
export function mapFollowerRows(rows: FollowerRow[]): UserProfile[] {
  return rows.map((row) => toUserProfile(row.follower));
}

/** Mirrors FollowService.pendingRequests(for:limit:). */
export async function fetchPendingRequests(
  client: SupabaseClient,
  userId: string,
  limit = 50
): Promise<UserProfile[]> {
  const { data, error } = await client
    .from("follows")
    .select("created_at, follower:profiles!follows_follower_id_fkey(*)")
    .eq("followee_id", userId)
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return mapFollowerRows(data as unknown as FollowerRow[]);
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd web && npm run test`
Expected: PASS — all tests green (Task 3's 2 tests plus Tasks 1-2's).

- [ ] **Step 5: Commit**

```bash
cd web
git add lib/follow.ts lib/__tests__/follow.test.ts
git commit -m "feat(web): add follow data layer, ported from FollowService.swift"
```

---

### Task 4: Public-profile lookup by username

**Files:**

- Modify: `web/lib/profile.ts`

**Interfaces:**

- Consumes: existing `toUserProfile`, `ProfileRow`, `UserProfile` in the same file.
- Produces: `fetchProfileByUsername(client: SupabaseClient, username: string): Promise<UserProfile | null>`.

- [ ] **Step 1: Add the function**

Open `web/lib/profile.ts` and add this function after the existing `fetchProfile`:

```ts
/** Looks up a profile by username — how public-profile URLs are addressed (/[username], not a UUID). */
export async function fetchProfileByUsername(
  client: SupabaseClient,
  username: string
): Promise<UserProfile | null> {
  const { data, error } = await client.from("profiles").select().eq("username", username).single();

  if (error) {
    if (error.code === "PGRST116") return null; // no matching row
    throw error;
  }
  return toUserProfile(data as ProfileRow);
}
```

No new test needed — this reuses `toUserProfile`, which `lib/__tests__/profile.test.ts` (Phase 1) already covers; the only new logic is the `.eq("username", ...)` filter, which is exercised by Task 10's E2E tests.

- [ ] **Step 2: Verify the file still builds**

Run: `cd web && npm run build`
Expected: build succeeds with no TypeScript errors.

- [ ] **Step 3: Commit**

```bash
cd web
git add lib/profile.ts
git commit -m "feat(web): add fetchProfileByUsername for public-profile lookups"
```

---

### Task 5: `VennOverlap` SVG component

**Files:**

- Create: `web/components/VennOverlap.tsx`

**Interfaces:**

- Consumes: `pairGeometry`, `VENN_DIAGRAM_HEIGHT` from `@/lib/vennGeometry` (Task 1); `tasteMatchPercent`, `type OverlapSummary` from `@/lib/overlap` (Task 2).
- Produces: `VennOverlap(props: { viewerLabel: string; otherLabel: string; summary: OverlapSummary }): JSX.Element` (default export).

Ports the `.pair` mode of `ios/Venn/Components/VennOverlap.swift` (SwiftUI's `.mask` becomes an SVG `<clipPath>` — same visual result: a solid accent-colored circle for the other lobe, clipped to the viewer lobe's shape, so only the intersection shows). The `.solo` mode isn't needed for Phase 2 (nothing in this phase's scope uses it — YAGNI).

- [ ] **Step 1: Write the component**

Create `web/components/VennOverlap.tsx`:

```tsx
import { pairGeometry, VENN_DIAGRAM_HEIGHT } from "@/lib/vennGeometry";
import { tasteMatchPercent, type OverlapSummary } from "@/lib/overlap";

const DIAGRAM_WIDTH = 360;

interface VennOverlapProps {
  viewerLabel: string;
  otherLabel: string;
  summary: OverlapSummary;
}

export function VennOverlap({ viewerLabel, otherLabel, summary }: VennOverlapProps) {
  const { viewerTotal, otherTotal, sharedTotal, kinds } = summary;
  const percent = tasteMatchPercent(sharedTotal, viewerTotal, otherTotal);
  const geometry = pairGeometry(viewerTotal, otherTotal, sharedTotal);
  const centerX = DIAGRAM_WIDTH / 2;
  const centerY = VENN_DIAGRAM_HEIGHT / 2;
  const viewerX = centerX - geometry.halfDistance;
  const otherX = centerX + geometry.halfDistance;
  const sharedKinds = kinds.filter((k) => k.sharedCount > 0);

  const accessibilityLabel = `${percent ?? 0}% taste match. ${sharedTotal} in common, ${
    viewerTotal - sharedTotal
  } only you, ${otherTotal - sharedTotal} only them.`;

  return (
    <div className="flex flex-col gap-4">
      {percent !== null && (
        <div className="flex flex-col items-center gap-0.5">
          <span className="text-4xl font-bold text-(--color-accent)">{percent}%</span>
          <span className="text-xs font-semibold tracking-wide text-(--color-text-secondary) uppercase">
            taste match
          </span>
        </div>
      )}

      <svg
        viewBox={`0 0 ${DIAGRAM_WIDTH} ${VENN_DIAGRAM_HEIGHT}`}
        width="100%"
        height={VENN_DIAGRAM_HEIGHT}
        role="img"
        aria-label={accessibilityLabel}
      >
        <defs>
          <clipPath id="venn-lens-clip">
            <circle cx={viewerX} cy={centerY} r={geometry.viewerRadius} />
          </clipPath>
        </defs>

        <circle
          cx={viewerX}
          cy={centerY}
          r={geometry.viewerRadius}
          fill="var(--color-graphite)"
          fillOpacity={0.08}
          stroke="var(--color-graphite)"
          strokeOpacity={0.45}
          strokeWidth={1.5}
        />
        <circle
          cx={otherX}
          cy={centerY}
          r={geometry.otherRadius}
          fill="var(--color-graphite)"
          fillOpacity={0.08}
          stroke="var(--color-graphite)"
          strokeOpacity={0.45}
          strokeWidth={1.5}
        />

        {/* The lens: the other lobe filled solid accent, clipped to the
            viewer lobe's shape, so only the intersection shows. */}
        <circle
          cx={otherX}
          cy={centerY}
          r={geometry.otherRadius}
          fill="var(--color-accent)"
          clipPath="url(#venn-lens-clip)"
        />

        <text
          x={viewerX - geometry.viewerRadius * 0.45}
          y={centerY}
          textAnchor="middle"
          dominantBaseline="middle"
          fontWeight={600}
          fill="var(--color-text-primary)"
        >
          {viewerTotal - sharedTotal}
        </text>
        <text
          x={otherX + geometry.otherRadius * 0.45}
          y={centerY}
          textAnchor="middle"
          dominantBaseline="middle"
          fontWeight={600}
          fill="var(--color-text-primary)"
        >
          {otherTotal - sharedTotal}
        </text>

        {sharedTotal > 0 && (
          <g>
            <rect
              x={centerX - 16}
              y={centerY - 12}
              width={32}
              height={24}
              rx={12}
              fill="var(--color-accent)"
              stroke="var(--color-background)"
              strokeWidth={2}
            />
            <text
              x={centerX}
              y={centerY}
              textAnchor="middle"
              dominantBaseline="middle"
              fontWeight={700}
              fill="var(--color-on-accent)"
            >
              {sharedTotal}
            </text>
          </g>
        )}
      </svg>

      <div className="flex flex-col gap-1">
        <LegendRow label={viewerLabel} count={viewerTotal - sharedTotal} />
        <LegendRow label="in common" count={sharedTotal} emphasized />
        <LegendRow label={otherLabel} count={otherTotal - sharedTotal} />
      </div>

      {sharedKinds.length > 0 && (
        <div className="flex flex-col gap-1">
          {sharedKinds.map((k) => (
            <div key={k.kind} className="flex items-center justify-between text-sm">
              <span className="text-(--color-text-primary)">
                {k.kind.charAt(0).toUpperCase() + k.kind.slice(1)}s in common
              </span>
              <span className="font-semibold text-(--color-text-secondary)">{k.sharedCount}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function LegendRow({
  label,
  count,
  emphasized = false
}: {
  label: string;
  count: number;
  emphasized?: boolean;
}) {
  return (
    <div className="flex items-center gap-2">
      <span
        className="h-2 w-2 rounded-full"
        style={{
          backgroundColor: emphasized ? "var(--color-accent)" : "var(--color-graphite)",
          opacity: emphasized ? 1 : 0.55
        }}
      />
      <span className={`flex-1 text-(--color-text-primary) ${emphasized ? "font-semibold" : ""}`}>
        {label}
      </span>
      <span className="text-(--color-text-secondary)">{count}</span>
    </div>
  );
}
```

Note: the legend dot's color/opacity uses inline `style`, not a Tailwind opacity-modifier class — deliberately, to avoid gambling on whether `bg-(--color-x)/55`-style stacking is supported in this Tailwind v4 version (see the Global Constraints note on the spacing-scale gotcha found in Phase 1; verify Tailwind syntax against real output before trusting it).

- [ ] **Step 2: Verify it builds**

Run: `cd web && npm run build`
Expected: build succeeds with no TypeScript errors. (This component isn't wired into a page yet — Task 8 does that — so there's no visual check until then.)

- [ ] **Step 3: Commit**

```bash
cd web
git add components/VennOverlap.tsx
git commit -m "feat(web): add VennOverlap SVG component, ported from VennOverlap.swift"
```

---

### Task 6: `LockedProfile` component

**Files:**

- Create: `web/components/LockedProfile.tsx`

**Interfaces:**

- Consumes: nothing.
- Produces: `LockedProfile(props: { username: string }): JSX.Element` (default export).

Ports `PublicProfileView`'s `lockedContent` (shown instead of the overlap/shelves when the account is private and the viewer isn't an accepted follower).

- [ ] **Step 1: Write the component**

Create `web/components/LockedProfile.tsx`:

```tsx
interface LockedProfileProps {
  username: string;
}

/**
 * Mirrors PublicProfileView's lockedContent — shown instead of the
 * overlap section and shelves when the account is private and the
 * viewer isn't an accepted follower yet.
 */
export function LockedProfile({ username }: LockedProfileProps) {
  return (
    <div className="flex flex-col items-center gap-2 py-12 text-center">
      <svg
        width="32"
        height="32"
        viewBox="0 0 24 24"
        fill="none"
        stroke="var(--color-text-secondary)"
        strokeWidth={1.5}
        aria-hidden
      >
        <rect x="5" y="11" width="14" height="10" rx="2" />
        <path d="M8 11V7a4 4 0 0 1 8 0v4" />
      </svg>
      <h2 className="text-lg font-semibold text-(--color-text-primary)">This account is private</h2>
      <p className="max-w-xs text-(--color-text-secondary)">
        Follow @{username} to see their posts and your taste overlap.
      </p>
    </div>
  );
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd web && npm run build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
cd web
git add components/LockedProfile.tsx
git commit -m "feat(web): add LockedProfile component, ported from PublicProfileView.swift"
```

---

### Task 7: `FollowButton` client component

**Files:**

- Create: `web/components/FollowButton.tsx`

**Interfaces:**

- Consumes: `createClient` from `@/lib/supabase/client`; `requestFollow`, `unfollow`, `type FollowStatus` from `@/lib/follow` (Task 3).
- Produces: `FollowButton(props: { followerId: string; followeeId: string; initialStatus: FollowStatus | null }): JSX.Element` (default export). Client Component (`"use client"`).

Ports `FollowViewModel.swift` and `PublicProfileView`'s `followButton`. Same optimism asymmetry: unfollow/cancel flips immediately and reverts on failure; starting a follow waits for the server's real answer since the result (`accepted` vs. `pending`) depends on the target's privacy.

- [ ] **Step 1: Write the component**

Create `web/components/FollowButton.tsx`:

```tsx
"use client";

import { useState, useTransition } from "react";
import { createClient } from "@/lib/supabase/client";
import { requestFollow, unfollow, type FollowStatus } from "@/lib/follow";

type ButtonState = "notFollowing" | "requested" | "following";

function toButtonState(status: FollowStatus | null): ButtonState {
  if (status === "accepted") return "following";
  if (status === "pending") return "requested";
  return "notFollowing";
}

interface FollowButtonProps {
  followerId: string;
  followeeId: string;
  initialStatus: FollowStatus | null;
}

export function FollowButton({ followerId, followeeId, initialStatus }: FollowButtonProps) {
  const [state, setState] = useState<ButtonState>(toButtonState(initialStatus));
  const [isPending, startTransition] = useTransition();

  function handleClick() {
    const supabase = createClient();

    if (state === "following" || state === "requested") {
      const previous = state;
      setState("notFollowing");
      startTransition(async () => {
        try {
          await unfollow(supabase, followerId, followeeId);
        } catch {
          setState(previous);
        }
      });
      return;
    }

    startTransition(async () => {
      try {
        const status = await requestFollow(supabase, followeeId);
        setState(toButtonState(status));
      } catch {
        setState("notFollowing");
      }
    });
  }

  const label =
    state === "following" ? "Following" : state === "requested" ? "Requested" : "Follow";
  const isPrimary = state === "notFollowing";

  return (
    <button
      type="button"
      onClick={handleClick}
      disabled={isPending}
      className={
        isPrimary
          ? "rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
          : "rounded-pill border border-(--color-separator) bg-(--color-surface-strong) px-4 py-2 font-semibold text-(--color-text-primary) disabled:opacity-50"
      }
    >
      {label}
    </button>
  );
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd web && npm run build`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
cd web
git add components/FollowButton.tsx
git commit -m "feat(web): add FollowButton client component, ported from FollowViewModel.swift"
```

---

### Task 8: Public-profile page (`app/[username]/page.tsx`)

**Files:**

- Create: `web/app/[username]/page.tsx`

**Interfaces:**

- Consumes: `fetchFollowCounts`, `fetchProfileByUsername` from `@/lib/profile`; `fetchFollowStatus` from `@/lib/follow`; `fetchOverlap` from `@/lib/overlap`; `FollowButton` from `@/components/FollowButton`; `LockedProfile` from `@/components/LockedProfile`; `VennOverlap` from `@/components/VennOverlap`; `createClient` from `@/lib/supabase/server`.
- Produces: the `/[username]` route.

Wires everything together: looks up the profile, gates content server-side, and renders the header/bio/follow-button/overlap or the locked state. Redirects to `/profile` if you visit your own username (mirrors iOS never using `PublicProfileView` for the signed-in user's own profile).

- [ ] **Step 1: Write the page**

Create `web/app/[username]/page.tsx`:

```tsx
import { notFound, redirect } from "next/navigation";
import { FollowButton } from "@/components/FollowButton";
import { LockedProfile } from "@/components/LockedProfile";
import { VennOverlap } from "@/components/VennOverlap";
import { fetchFollowStatus } from "@/lib/follow";
import { fetchOverlap } from "@/lib/overlap";
import { fetchFollowCounts, fetchProfileByUsername } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";

interface PublicProfilePageProps {
  params: Promise<{ username: string }>;
}

export default async function PublicProfilePage({ params }: PublicProfilePageProps) {
  const { username } = await params;
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const profile = await fetchProfileByUsername(supabase, username);
  if (!profile) {
    notFound();
  }
  if (profile.id === user.id) {
    redirect("/profile");
  }

  const [counts, followStatus] = await Promise.all([
    fetchFollowCounts(supabase, profile.id),
    fetchFollowStatus(supabase, user.id, profile.id)
  ]);

  const isLocked = profile.isPrivate && followStatus !== "accepted";
  const overlap = isLocked ? null : await fetchOverlap(supabase, profile.id);
  const initial = (profile.displayName ?? profile.username).charAt(0).toUpperCase();

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
      <div className="flex items-start gap-3">
        <div className="flex h-[72px] w-[72px] shrink-0 items-center justify-center rounded-full bg-(--color-graphite) text-xl font-semibold text-(--color-on-accent)">
          {initial}
        </div>
        <div className="flex flex-col gap-0.5">
          <h1 className="text-xl font-semibold text-(--color-text-primary)">
            {profile.displayName ?? profile.username}
          </h1>
          <p className="text-(--color-text-secondary)">@{profile.username}</p>
          <div className="mt-1 flex gap-4 text-sm text-(--color-text-secondary)">
            <span>
              <strong className="font-medium">{counts.followers}</strong> Followers
            </span>
            <span>
              <strong className="font-medium">{counts.following}</strong> Following
            </span>
          </div>
        </div>
      </div>

      {profile.bio && <p className="text-(--color-text-primary)">{profile.bio}</p>}

      <FollowButton followerId={user.id} followeeId={profile.id} initialStatus={followStatus} />

      {isLocked ? (
        <LockedProfile username={profile.username} />
      ) : overlap ? (
        <VennOverlap
          viewerLabel="Only you"
          otherLabel={`Only @${profile.username}`}
          summary={overlap}
        />
      ) : null}
    </main>
  );
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd web && npm run build`
Expected: build succeeds; the route table includes `ƒ /[username]`.

- [ ] **Step 3: Manual check**

Run: `cd web && npm run dev`, sign in, then visit `http://localhost:3000/<a-real-username-in-the-database>`.
Expected: profile renders with header, bio, follow button, and (if not locked) the Venn overlap diagram. Visiting your own username redirects to `/profile`. Visiting a nonexistent username shows the Next.js 404 page.

- [ ] **Step 4: Commit**

```bash
cd web
git add "app/[username]/page.tsx"
git commit -m "feat(web): add public-profile page, ported from PublicProfileView.swift"
```

---

### Task 9: Follow-requests screen

**Files:**

- Create: `web/components/RequestsList.tsx`
- Create: `web/app/requests/page.tsx`

**Interfaces:**

- Consumes: `respondToRequest` from `@/lib/follow`; `createClient` (browser) from `@/lib/supabase/client`; `createClient` (server) from `@/lib/supabase/server`; `fetchPendingRequests` from `@/lib/follow`; `type UserProfile` from `@/lib/profile`.
- Produces: the `/requests` route; `RequestsList(props: { initialRequests: UserProfile[] }): JSX.Element` (default export, Client Component).

Ports `FollowRequestsViewModel.swift` and `FollowRequestsView.swift`: the signed-in user's pending follow requests, with inline accept/reject and optimistic removal (reverts by re-adding the request back to the list on failure — matches the view-model's reload-on-failure behavior in spirit, but avoids an extra round trip since the client already has the pre-removal item in hand).

- [ ] **Step 1: Write the client list component**

Create `web/components/RequestsList.tsx`:

```tsx
"use client";

import { useState } from "react";
import { respondToRequest } from "@/lib/follow";
import type { UserProfile } from "@/lib/profile";
import { createClient } from "@/lib/supabase/client";

interface RequestsListProps {
  initialRequests: UserProfile[];
}

export function RequestsList({ initialRequests }: RequestsListProps) {
  const [requests, setRequests] = useState(initialRequests);
  const [respondingTo, setRespondingTo] = useState<Set<string>>(new Set());

  async function handleRespond(requester: UserProfile, accept: boolean) {
    if (respondingTo.has(requester.id)) return;
    setRespondingTo((prev) => new Set(prev).add(requester.id));
    setRequests((prev) => prev.filter((r) => r.id !== requester.id));

    const supabase = createClient();
    try {
      await respondToRequest(supabase, requester.id, accept);
    } catch {
      setRequests((prev) => [...prev, requester]);
    } finally {
      setRespondingTo((prev) => {
        const next = new Set(prev);
        next.delete(requester.id);
        return next;
      });
    }
  }

  if (requests.length === 0) {
    return (
      <p className="text-(--color-text-secondary)">
        Requests to follow your private account will show up here.
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      {requests.map((requester) => {
        const isResponding = respondingTo.has(requester.id);
        const initial = (requester.displayName ?? requester.username).charAt(0).toUpperCase();
        return (
          <div
            key={requester.id}
            className="flex items-center gap-3 rounded-lg bg-(--color-surface) p-3"
          >
            <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-(--color-graphite) text-sm font-semibold text-(--color-on-accent)">
              {initial}
            </div>
            <div className="flex flex-1 flex-col">
              <span className="font-medium text-(--color-text-primary)">
                {requester.displayName ?? requester.username}
              </span>
              <span className="text-sm text-(--color-text-secondary)">@{requester.username}</span>
            </div>
            <button
              type="button"
              onClick={() => handleRespond(requester, false)}
              disabled={isResponding}
              aria-label="Decline"
              className="flex h-8 w-8 items-center justify-center rounded-full bg-(--color-surface-strong) text-(--color-text-secondary) disabled:opacity-40"
            >
              ✕
            </button>
            <button
              type="button"
              onClick={() => handleRespond(requester, true)}
              disabled={isResponding}
              aria-label="Accept"
              className="flex h-8 w-8 items-center justify-center rounded-full bg-(--color-surface-strong) text-(--color-accent) disabled:opacity-40"
            >
              ✓
            </button>
          </div>
        );
      })}
    </div>
  );
}
```

- [ ] **Step 2: Write the page**

Create `web/app/requests/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { RequestsList } from "@/components/RequestsList";
import { fetchPendingRequests } from "@/lib/follow";
import { createClient } from "@/lib/supabase/server";

export default async function RequestsPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const requests = await fetchPendingRequests(supabase, user.id);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Follow Requests</h1>
      <RequestsList initialRequests={requests} />
    </main>
  );
}
```

- [ ] **Step 3: Verify it builds**

Run: `cd web && npm run build`
Expected: build succeeds; the route table includes `ƒ /requests`.

- [ ] **Step 4: Manual check**

Run: `cd web && npm run dev`, sign in as a user with at least one pending follow request, visit `http://localhost:3000/requests`.
Expected: pending requesters list with working accept/reject buttons; empty state when there are none.

- [ ] **Step 5: Commit**

```bash
cd web
git add components/RequestsList.tsx app/requests/page.tsx
git commit -m "feat(web): add follow-requests screen, ported from FollowRequestsView.swift"
```

---

### Task 10: Playwright auth-gate coverage + FollowButton unit tests

**Files:**

- Create: `web/e2e/profile.spec.ts`
- Create: `web/components/__tests__/FollowButton.test.tsx`

**Interfaces:**

- Consumes: the `/[username]` and `/requests` routes (Tasks 8-9); `FollowButton` (Task 7), which itself consumes `requestFollow`/`unfollow` from `@/lib/follow` (Task 3) and `createClient` from `@/lib/supabase/client`.
- Produces: no new production code — test coverage only.

**Correction vs. the original Task 10 draft:** `/[username]` (Task 8) and `/requests` (Task 9) both `redirect("/login")` for a signed-out visitor before doing anything else — confirmed by reading the shipped `app/[username]/page.tsx` and `app/requests/page.tsx`, and independently by curling a running build while signed out (both return `307` → `/login`, for a real username and a nonexistent one alike). This project has no authenticated Playwright fixture — no test Supabase user, no `storageState`, no admin/service-role key wired into test config — and `e2e/auth.spec.ts` (Phase 1) never completes a real sign-in either, only the OTP-send request. Building one now (a dedicated test user + a service-role-key-backed session-minting step) is real new infrastructure with its own security surface (a service role key would need to exist somewhere in CI), out of proportion to this task — flagged as a follow-up, not built here.

Given that, this task covers what's genuinely real and automatable without a session: (a) Playwright E2E for the auth gate itself on both routes — a real, valuable security-boundary check, and (b) a component-level Vitest + React Testing Library test for `FollowButton`'s click behavior (Follow/Following/Requested state transitions, and the optimism asymmetry from `FollowViewModel.swift` — unfollow flips immediately, follow waits for the server) by rendering the component directly and mocking `@/lib/follow` and `@/lib/supabase/client`. This needs no server, no session, and no network — and it is strictly better coverage of the follow/unfollow interaction than the original page-level E2E draft would have been, since it asserts the mid-flight (pre-resolve) button state directly, which a page-level test cannot easily observe.

`@testing-library/react` and `jsdom` are already dependencies (used by no test yet) — no new package needed. `@testing-library/jest-dom`'s matchers (e.g. `toBeInTheDocument`) are NOT wired into `vitest.config.ts` (no `setupFiles` entry exists) — do not use them and do not add the wiring for this one file (YAGNI); use `getByRole`/`findByRole` directly, which throw when a match isn't found, as the assertion.

- [ ] **Step 1: Write the E2E auth-gate tests**

Create `web/e2e/profile.spec.ts`:

```ts
import { expect, test } from "@playwright/test";

/**
 * `/[username]` and `/requests` both require a signed-in session (see
 * app/[username]/page.tsx and app/requests/page.tsx) — real interactive
 * sign-in isn't automatable here (magic-link auth, no test-user fixture
 * exists yet), so this suite covers the one thing that's genuinely real
 * and testable without one: the auth gate itself. FollowButton's
 * click behavior is covered instead by
 * components/__tests__/FollowButton.test.tsx (Vitest + RTL, mocks
 * lib/follow directly — no server or session needed).
 */
test.describe("auth gate", () => {
  test("visiting a public profile while signed out redirects to /login", async ({ page }) => {
    await page.goto("/venn");
    await expect(page).toHaveURL("/login");
  });

  test("visiting a nonexistent username while signed out redirects to /login", async ({ page }) => {
    await page.goto("/this-username-should-not-exist-anywhere-12345");
    await expect(page).toHaveURL("/login");
  });

  test("visiting /requests while signed out redirects to /login", async ({ page }) => {
    await page.goto("/requests");
    await expect(page).toHaveURL("/login");
  });
});
```

- [ ] **Step 2: Run the E2E suite**

Run: `cd web && npm run test:e2e`
Expected: PASS (3/3).

- [ ] **Step 3: Write the FollowButton unit tests**

Create `web/components/__tests__/FollowButton.test.tsx`:

```tsx
import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { FollowButton } from "@/components/FollowButton";

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({})
}));

const { requestFollow, unfollow } = vi.hoisted(() => ({
  requestFollow: vi.fn(),
  unfollow: vi.fn()
}));

vi.mock("@/lib/follow", () => ({
  requestFollow,
  unfollow
}));

describe("FollowButton", () => {
  beforeEach(() => {
    requestFollow.mockReset();
    unfollow.mockReset();
  });

  it("starts on Follow when there is no existing status", () => {
    render(<FollowButton followerId="me" followeeId="them" initialStatus={null} />);
    expect(screen.getByRole("button", { name: "Follow" })).toBeDefined();
  });

  it("starts on Following when the initial status is accepted", () => {
    render(<FollowButton followerId="me" followeeId="them" initialStatus="accepted" />);
    expect(screen.getByRole("button", { name: "Following" })).toBeDefined();
  });

  it("starts on Requested when the initial status is pending", () => {
    render(<FollowButton followerId="me" followeeId="them" initialStatus="pending" />);
    expect(screen.getByRole("button", { name: "Requested" })).toBeDefined();
  });

  it("waits for the server before flipping Follow to Following (no optimism on follow)", async () => {
    let resolveRequest: (status: "accepted" | "pending") => void = () => {};
    requestFollow.mockReturnValue(
      new Promise((resolve) => {
        resolveRequest = resolve;
      })
    );

    render(<FollowButton followerId="me" followeeId="them" initialStatus={null} />);
    fireEvent.click(screen.getByRole("button", { name: "Follow" }));

    // Still "Follow" immediately after the click — the button doesn't
    // guess the outcome, since a private target resolves to "pending"
    // instead of "accepted".
    expect(screen.getByRole("button", { name: "Follow" })).toBeDefined();

    resolveRequest("accepted");
    await screen.findByRole("button", { name: "Following" });
  });

  it("requesting a private account lands on Requested, not Following", async () => {
    requestFollow.mockResolvedValue("pending");

    render(<FollowButton followerId="me" followeeId="them" initialStatus={null} />);
    fireEvent.click(screen.getByRole("button", { name: "Follow" }));

    await screen.findByRole("button", { name: "Requested" });
  });

  it("reverts to Follow if the follow request fails", async () => {
    requestFollow.mockRejectedValue(new Error("network"));

    render(<FollowButton followerId="me" followeeId="them" initialStatus={null} />);
    fireEvent.click(screen.getByRole("button", { name: "Follow" }));

    await screen.findByRole("button", { name: "Follow" });
  });

  it("flips Following to Follow immediately on unfollow (optimistic)", async () => {
    let resolveUnfollow: () => void = () => {};
    unfollow.mockReturnValue(
      new Promise<void>((resolve) => {
        resolveUnfollow = resolve;
      })
    );

    render(<FollowButton followerId="me" followeeId="them" initialStatus="accepted" />);
    fireEvent.click(screen.getByRole("button", { name: "Following" }));

    // Flips immediately, before the server call resolves — the optimism
    // asymmetry from FollowViewModel.swift: unfollow's outcome is never
    // in doubt, so the UI doesn't wait for it.
    expect(screen.getByRole("button", { name: "Follow" })).toBeDefined();

    resolveUnfollow();
    await vi.waitFor(() => {
      expect(unfollow).toHaveBeenCalledWith({}, "me", "them");
    });
  });

  it("reverts to Following if the unfollow call fails", async () => {
    unfollow.mockRejectedValue(new Error("network"));

    render(<FollowButton followerId="me" followeeId="them" initialStatus="accepted" />);
    fireEvent.click(screen.getByRole("button", { name: "Following" }));

    await screen.findByRole("button", { name: "Following" });
  });
});
```

- [ ] **Step 4: Run the unit tests**

Run: `cd web && npm run test`
Expected: PASS — the existing 16 tests plus these 8 new ones (24 total).

- [ ] **Step 5: Commit**

```bash
cd web
git add e2e/profile.spec.ts components/__tests__/FollowButton.test.tsx
git commit -m "test(web): add auth-gate E2E coverage and FollowButton unit tests"
```

---

## Self-Review Notes

**Spec coverage:** Public profile page (Task 8), full follow lifecycle — follow/unfollow (Task 7), requests screen (Task 9) — private-account gating (Task 8, server-side `isLocked`), Venn overlap (Tasks 1, 2, 5). All five Phase 2 scope bullets have a task. The one open question in the spec (people-search / profile discovery) is explicitly out of scope and untouched here, as the spec says.

**Type consistency:** `FollowStatus` (Task 3) is consumed as-is by `FollowButton` (Task 7) and the public-profile page (Task 8) — no renaming across tasks. `OverlapSummary`/`KindOverlap` (Task 2) flow unchanged into `VennOverlap` (Task 5) and the page (Task 8). `UserProfile` (Phase 1, unchanged) flows into `RequestsList` (Task 9) and `mapFollowerRows` (Task 3).

**Scope:** Kept the `.solo` Venn-overlap mode out (Task 5) — nothing in Phase 2 needs it (the own-profile page doesn't render an overlap in Phase 1 either). If a later phase wants a solo mode on `/profile`, that's a small follow-up to `VennOverlap.tsx`, not a Phase 2 gap.
