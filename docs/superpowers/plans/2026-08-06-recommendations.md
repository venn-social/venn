# Recommendations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Explorer tab's unranked browse grid with labelled recommendation shelves that work from a user's first log and improve on their own as venn gathers data.

**Architecture:** A `security invoker` Postgres RPC produces the tiers that come from venn's own data (taste twins, people you follow) and hands back seeds plus an exclusion list. Each client tops that up from the catalog APIs (similar-to-seed, trending), then runs one **pure** `assembleShelves` function that filters, dedups, drops thin shelves and caps the total. Everything else is platform-native.

**Tech Stack:** Postgres 15 / Supabase RPC, Next.js 16 App Router + TypeScript + Vitest, Swift 6 + SwiftUI (iOS 26) + Swift Testing.

**Spec:** [`docs/superpowers/specs/2026-08-06-recommendations-design.md`](../specs/2026-08-06-recommendations-design.md)

## Global Constraints

- Never push to `main`. Branch → PR → squash merge (CLAUDE.md rule 1).
- `make verify` must pass before any PR (rule 4). Web: `npm run test`, `npx tsc --noEmit`, `npm run lint`.
- Never hardcode colours, spacing or font sizes — use `ios/Venn/Components/Theme.swift` tokens and the `--color-*` CSS variables (rule 5).
- No force unwraps, no `try!`, no `as!` outside tests (rules 11, 12).
- Views call view-models, view-models call services, services call Supabase. One direction (rule 10).
- Use the shared `LoadState` / `LoadErrorReason` machine from `ios/Venn/Models/LoadState.swift`. Never declare a per-feature loading enum.
- iOS is component-first: one component per file, feature subfolders (rule 16).
- iOS and web ship together with matching copy (rule 17). Any gap goes in `docs/TECH_DEBT.md`.
- Schema changes are migration files in `supabase/migrations/`. Never run SQL against production directly (rule 14).
- Commit messages are Conventional Commits. **Never put `#` followed by a word or number in a commit body** — commitlint parses it as an issue reference and fails.
- Node must be v24 for web commands: `export PATH="$HOME/.nvm/versions/node/v24.18.1/bin:$PATH"`.
- Prettier is pinned: always `npx prettier@3.9.6`, never bare `npx prettier`.
- **Exclusion key is `"<source>:<kind>:<externalId>"` everywhere.** Both platforms, SQL included.
- Shelf rules, fixed: minimum **3** items to show a shelf, maximum **4** shelves, maximum **12** items per shelf, at most **5** seeds.
- Tier order: `taste_twins` → `followed` → `similar` (one shelf per seed) → `trending`.

## File Structure

| File                                                                        | Responsibility                                     |
| --------------------------------------------------------------------------- | -------------------------------------------------- |
| `supabase/migrations/20260806120000_recommendations.sql`                    | `similar_users()` + `recommendation_feed()`        |
| `ios/Venn/Models/MediaCandidate.swift`                                      | **modify** — put `kind` in `id`                    |
| `web/lib/recommendations.ts`                                                | Types + `assembleShelves` (pure)                   |
| `web/lib/catalog/similar.ts`                                                | Per-provider similar + trending fetchers           |
| `web/components/RecommendationShelves.tsx`                                  | Renders shelves                                    |
| `web/components/Explorer.tsx`                                               | **modify** — render shelves under the search bar   |
| `ios/Venn/Features/Explorer/Recommendations/RecommendationService.swift`    | RPC + models                                       |
| `ios/Venn/Features/Explorer/Recommendations/RecommendationAssembler.swift`  | `assembleShelves` (pure)                           |
| `ios/Venn/Features/Explorer/Recommendations/CatalogSimilarService.swift`    | Per-provider similar + trending                    |
| `ios/Venn/Features/Explorer/Recommendations/RecommendationsViewModel.swift` | `LoadState` machine                                |
| `ios/Venn/Features/Explorer/Recommendations/RecommendationShelfView.swift`  | One shelf                                          |
| `ios/Venn/Features/Explorer/Recommendations/RecommendationsView.swift`      | The stack of shelves                               |
| `ios/Venn/Features/Explorer/ExplorerView.swift`                             | **modify** — render shelves under the search field |

---

### Task 1: Make the exclusion key identical on both platforms

iOS's `MediaCandidate.id` is `"<source>:<externalId>"`; web's `candidateId()` is `"<source>:<kind>:<externalId>"`. TMDB numbers movies and TV independently, so on iOS movie 123 and show 123 currently collide. Nothing depends on the current shape (verified by grep), and every later task uses this key to filter and dedup — so it has to be right before anything else is built.

**Files:**

- Modify: `ios/Venn/Models/MediaCandidate.swift`
- Test: `ios/VennTests/Models/MediaCandidateTests.swift` (create)

**Interfaces:**

- Produces: `MediaCandidate.id -> String`, formatted `"<externalSource.rawValue>:<kind.rawValue>:<externalID>"`

- [ ] **Step 1: Write the failing test**

Create `ios/VennTests/Models/MediaCandidateTests.swift`:

```swift
import Foundation
import Testing
@testable import Venn

struct MediaCandidateTests {
    private func candidate(kind: MediaKind, externalID: String) -> MediaCandidate {
        MediaCandidate(
            title: "Thing",
            primaryCreator: nil,
            year: nil,
            coverURL: nil,
            overview: nil,
            externalID: externalID,
            externalSource: .tmdb,
            kind: kind
        )
    }

    @Test
    func kindIsPartOfTheIdentity() {
        // TMDB numbers movies and TV independently, so movie 123 and show
        // 123 are different things. Without kind in the key they collide —
        // visibly so in Explorer's "All" category, which searches both.
        #expect(candidate(kind: .movie, externalID: "123").id
            != candidate(kind: .show, externalID: "123").id)
    }

    @Test
    func matchesTheFormatWebUses() {
        // web/lib/catalog/types.ts candidateId() builds the same string.
        // Recommendations filter "already seen" by comparing these across
        // platforms, so the format is a contract, not an implementation
        // detail.
        #expect(candidate(kind: .movie, externalID: "666277").id == "tmdb:movie:666277")
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
cd /Users/charlessalomon/GitProjects/venn
make project
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData \
  -only-testing:VennTests/MediaCandidateTests test 2>&1 | xcbeautify --quiet
```

Expected: `matchesTheFormatWebUses` fails — actual is `"tmdb:666277"`.

- [ ] **Step 3: Fix the identity**

In `ios/Venn/Models/MediaCandidate.swift` replace the `id` property:

```swift
struct MediaCandidate: Equatable, Identifiable {
    /// `"<source>:<kind>:<externalId>"`, byte-identical to web's
    /// `candidateId()`. Kind is load-bearing: TMDB numbers movies and TV
    /// independently, so movie 123 and show 123 are different things that
    /// would otherwise collide. Recommendations compare this key across
    /// platforms to filter out what you have already seen.
    var id: String {
        "\(externalSource.rawValue):\(kind.rawValue):\(externalID)"
    }
```

- [ ] **Step 4: Run the whole suite**

```bash
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData -only-testing:VennTests test 2>&1 \
  | xcbeautify --quiet | grep -E "✘|Test run with"
```

Expected: `Test run with N tests ... passed`. If a composer test asserted the old string, update it — the new format is correct.

- [ ] **Step 5: Commit**

```bash
git add ios/Venn/Models/MediaCandidate.swift ios/VennTests/Models/MediaCandidateTests.swift
git commit -m "fix(ios): put kind in the media candidate identity

TMDB numbers movies and TV independently, so movie 123 and show 123
collided under the old source-and-id key. Web already keyed on kind;
this brings iOS to the same format, which recommendations rely on to
filter out what you have already seen."
```

---

### Task 2: The RPC

**Files:**

- Create: `supabase/migrations/20260806120000_recommendations.sql`

**Interfaces:**

- Produces: `public.similar_users(_limit int) returns table (user_id uuid, similarity numeric, shared_count bigint)`
- Produces: `public.recommendation_feed(_seed_limit int, _per_section int) returns jsonb`

- [ ] **Step 1: Write the migration**

Create `supabase/migrations/20260806120000_recommendations.sql`:

```sql
-- =============================================================================
-- 20260806120000_recommendations.sql — the venn-data half of recommendations.
-- =============================================================================
-- Two tiers come from our own data: people whose taste matches yours, and
-- people you follow. The other two (similar-to-what-you-loved, trending)
-- need external catalogs and are fetched per client — Postgres cannot call
-- TMDB.
--
-- Both functions are `security invoker` on purpose. Recommendations derive
-- from other people's logs, so the privacy boundary is load-bearing: RLS
-- already hides a private account's posts from non-followers, and running
-- as the caller means that protection applies here for free rather than
-- being re-implemented (and eventually got wrong).
--
-- Idempotent: safe to replay.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- similar_users(_limit) — who shares your taste.
-- -----------------------------------------------------------------------------
-- Jaccard similarity over consumed sets, reusing the definition
-- compute_overlap established: consumed means logged or rated. A watchlist
-- entry is an intention, not a verdict, so `saved` is excluded from both
-- sides.
create or replace function public.similar_users(_limit int default 20)
returns table (
  user_id uuid,
  similarity numeric,
  shared_count bigint
)
language sql
security invoker
stable
set search_path = ''
as $$
  with viewer_media as (
    select distinct p.media_id
      from public.posts p
     where p.author_id = (select auth.uid())
       and p.action in ('logged'::public.post_action, 'rated'::public.post_action)
  ),
  viewer_total as (
    select count(*)::bigint as n from viewer_media
  ),
  others as (
    select distinct p.author_id, p.media_id
      from public.posts p
     where p.author_id <> (select auth.uid())
       and p.action in ('logged'::public.post_action, 'rated'::public.post_action)
  ),
  scored as (
    select o.author_id,
           count(*) filter (where v.media_id is not null)::bigint as shared,
           count(*)::bigint as other_total
      from others o
      left join viewer_media v on v.media_id = o.media_id
     group by o.author_id
  )
  select s.author_id as user_id,
         round(
           s.shared::numeric
           / nullif((select n from viewer_total) + s.other_total - s.shared, 0),
           4
         ) as similarity,
         s.shared as shared_count
    from scored s
   where s.shared > 0
   order by similarity desc nulls last, s.shared desc
   limit _limit;
$$;

revoke execute on function public.similar_users(int) from public, anon;
grant execute on function public.similar_users(int) to authenticated;

-- -----------------------------------------------------------------------------
-- recommendation_feed(_seed_limit, _per_section) — everything SQL can know.
-- -----------------------------------------------------------------------------
-- Returns one jsonb document rather than several result sets: the client
-- needs all of it to assemble a single screen, and one round trip beats
-- four.
--
-- Empty sections and empty seeds are normal, not errors. A brand-new user
-- gets empty everything and sees only the client's trending shelf.
create or replace function public.recommendation_feed(
  _seed_limit int default 5,
  _per_section int default 12
)
returns jsonb
language plpgsql
security invoker
stable
set search_path = ''
as $$
declare
  viewer uuid := (select auth.uid());
  seen uuid[];
  twins uuid[];
  twin_items jsonb;
  followed_items jsonb;
  seed_items jsonb;
  excluded_keys jsonb;
begin
  if viewer is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  -- Every media row the viewer has touched at all — consumed, rated, or
  -- put on their watchlist. One array, applied to every tier: recommending
  -- something already on your watchlist is useless, and recommending
  -- something you disliked is worse.
  select coalesce(array_agg(distinct p.media_id), '{}')
    into seen
    from public.posts p
   where p.author_id = viewer;

  select coalesce(array_agg(su.user_id), '{}')
    into twins
    from public.similar_users(20) su;

  -- Tier 1 — what the taste twins loved, most-shared first.
  select coalesce(jsonb_agg(x.media order by x.votes desc, x.newest desc), '[]'::jsonb)
    into twin_items
    from (
      select to_jsonb(m) as media,
             count(*) as votes,
             max(p.created_at) as newest
        from public.posts p
        join public.media m on m.id = p.media_id
       where p.author_id = any(twins)
         and p.rating >= 3
         and not (p.media_id = any(seen))
       group by m.id
       order by votes desc, newest desc
       limit _per_section
    ) x;

  -- Tier 2 — what the people you follow loved, newest first. Only accepted
  -- follows: a pending request to a private account grants nothing.
  select coalesce(jsonb_agg(x.media order by x.newest desc), '[]'::jsonb)
    into followed_items
    from (
      select to_jsonb(m) as media,
             max(p.created_at) as newest
        from public.posts p
        join public.media m on m.id = p.media_id
        join public.follows f on f.followee_id = p.author_id
       where f.follower_id = viewer
         and f.status = 'accepted'
         and p.rating >= 3
         and not (p.media_id = any(seen))
       group by m.id
       order by newest desc
       limit _per_section
    ) x;

  -- Seeds for tier 3. Only rows with an external identity: a hand-typed
  -- entry has no catalog to ask for similar titles.
  select coalesce(jsonb_agg(s.obj), '[]'::jsonb)
    into seed_items
    from (
      select jsonb_build_object(
               'media_id', m.id,
               'title', m.title,
               'kind', m.kind,
               'external_source', m.external_source,
               'external_id', m.external_id,
               'rating', p.rating
             ) as obj
        from public.posts p
        join public.media m on m.id = p.media_id
       where p.author_id = viewer
         and p.rating >= 3
         and m.external_source is not null
         and m.external_id is not null
       order by p.rating desc, p.created_at desc
       limit _seed_limit
    ) s;

  -- The exclusion list the client filters catalog results through. Keyed
  -- source:kind:id — kind matters because TMDB numbers movies and TV
  -- independently. Capped at 500: past that the payload costs more than
  -- the occasional duplicate it prevents.
  select coalesce(jsonb_agg(e.obj), '[]'::jsonb)
    into excluded_keys
    from (
      select jsonb_build_object(
               'source', m.external_source,
               'kind', m.kind,
               'id', m.external_id
             ) as obj
        from public.posts p
        join public.media m on m.id = p.media_id
       where p.author_id = viewer
         and m.external_source is not null
         and m.external_id is not null
       group by m.external_source, m.kind, m.external_id
       order by max(p.created_at) desc
       limit 500
    ) e;

  return jsonb_build_object(
    'sections', (
      select coalesce(jsonb_agg(s.obj order by s.ord), '[]'::jsonb)
        from (
          select 1 as ord,
                 jsonb_build_object('source', 'taste_twins', 'items', twin_items) as obj
           where jsonb_array_length(twin_items) > 0
          union all
          select 2,
                 jsonb_build_object('source', 'followed', 'items', followed_items)
           where jsonb_array_length(followed_items) > 0
        ) s
    ),
    'seeds', seed_items,
    'excluded', excluded_keys
  );
end;
$$;

revoke execute on function public.recommendation_feed(int, int) from public, anon;
grant execute on function public.recommendation_feed(int, int) to authenticated;
```

- [ ] **Step 2: Apply it**

```bash
cd /Users/charlessalomon/GitProjects/venn
npm run db:push
```

Expected: the migration applies with no error.

- [ ] **Step 3: Verify by hand**

This repo has no SQL test harness, so verification is manual and must actually be done. In the Supabase SQL editor, run as an authenticated user:

```sql
select public.recommendation_feed();
```

Check all four:

1. The result has exactly the keys `sections`, `seeds`, `excluded`.
2. `seeds` contains only items you rated 3 or 5, and every entry has a non-null `external_source` and `external_id`.
3. No `media_id` you have logged, rated, or saved appears in any section's `items`.
4. Every `excluded` entry has `source`, `kind` and `id`.

- [ ] **Step 4: Verify the privacy boundary**

The single most important check. As user A, follow nobody. Have user B (a **private** account, `profiles.is_private = true`) log and rate something. Run `select public.recommendation_feed();` as A.

Expected: B's item does **not** appear. If it does, `security invoker` is not doing its job and nothing else in this plan should be built until it is.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260806120000_recommendations.sql
git commit -m "feat(db): add the recommendation feed RPC

Two tiers come from venn's own data: people whose taste matches yours,
and people you follow. Both run security invoker so RLS decides who can
contribute — a private account's posts stay invisible to non-followers
without a new policy."
```

---

### Task 3: Web — types and the pure assembler

The one piece of logic that exists on both platforms. Pure, so it carries the real test coverage.

**Files:**

- Create: `web/lib/recommendations.ts`
- Test: `web/lib/__tests__/recommendations.test.ts`

**Interfaces:**

- Consumes: `MediaCandidate`, `candidateId` from `@/lib/catalog/types`; `Media`, `MediaRow`, `toMedia` from `@/lib/media`
- Produces:
  - `type ShelfSource = "taste_twins" | "followed" | "similar" | "trending"`
  - `interface Shelf { source: ShelfSource; seedTitle: string | null; items: ShelfItem[] }`
  - `type ShelfItem = { kind: "media"; media: Media } | { kind: "candidate"; candidate: MediaCandidate }`
  - `interface RecommendationFeed { sections: FeedSection[]; seeds: Seed[]; excluded: ExcludedKey[] }`
  - `assembleShelves(feed: RecommendationFeed, candidateShelves: CandidateShelf[]): Shelf[]`
  - `MIN_SHELF_ITEMS = 3`, `MAX_SHELVES = 4`, `MAX_SHELF_ITEMS = 12`

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/recommendations.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import {
  assembleShelves,
  type CandidateShelf,
  type RecommendationFeed
} from "@/lib/recommendations";
import type { MediaCandidate } from "@/lib/catalog/types";

function mediaRow(id: string, title: string) {
  return {
    id,
    kind: "movie",
    title,
    year: 2023,
    primary_creator: null,
    cover_url: null,
    external_id: `ext-${id}`,
    external_source: "tmdb",
    created_at: "2026-01-01T00:00:00Z",
    genres: []
  };
}

function candidate(externalId: string, title = "Candidate"): MediaCandidate {
  return {
    id: `tmdb:movie:${externalId}`,
    title,
    primaryCreator: null,
    year: null,
    coverUrl: null,
    overview: null,
    externalId,
    externalSource: "tmdb",
    kind: "movie"
  };
}

const emptyFeed: RecommendationFeed = { sections: [], seeds: [], excluded: [] };

describe("assembleShelves", () => {
  it("returns nothing when there is nothing", () => {
    expect(assembleShelves(emptyFeed, [])).toEqual([]);
  });

  it("drops a shelf with fewer than three items", () => {
    // Two covers under a heading reads as broken, not as a recommendation.
    const shelves = assembleShelves(emptyFeed, [
      { source: "trending", seedTitle: null, candidates: [candidate("1"), candidate("2")] }
    ]);
    expect(shelves).toEqual([]);
  });

  it("keeps a shelf with exactly three", () => {
    const shelves = assembleShelves(emptyFeed, [
      {
        source: "trending",
        seedTitle: null,
        candidates: [candidate("1"), candidate("2"), candidate("3")]
      }
    ]);
    expect(shelves).toHaveLength(1);
    expect(shelves[0].items).toHaveLength(3);
  });

  it("never shows something the viewer has already seen", () => {
    const feed: RecommendationFeed = {
      ...emptyFeed,
      excluded: [{ source: "tmdb", kind: "movie", id: "2" }]
    };
    const shelves = assembleShelves(feed, [
      {
        source: "trending",
        seedTitle: null,
        candidates: [candidate("1"), candidate("2"), candidate("3"), candidate("4")]
      }
    ]);
    expect(shelves[0].items).toHaveLength(3);
    expect(JSON.stringify(shelves)).not.toContain('"externalId":"2"');
  });

  it("excludes on kind as well as id", () => {
    // TMDB movie 5 and show 5 are different things; excluding the movie
    // must not hide the show.
    const feed: RecommendationFeed = {
      ...emptyFeed,
      excluded: [{ source: "tmdb", kind: "movie", id: "5" }]
    };
    const show: MediaCandidate = { ...candidate("5"), kind: "show", id: "tmdb:show:5" };
    const shelves = assembleShelves(feed, [
      {
        source: "trending",
        seedTitle: null,
        candidates: [show, candidate("6"), candidate("7")]
      }
    ]);
    expect(shelves[0].items).toHaveLength(3);
  });

  it("shows an item once, in the highest tier that has it", () => {
    const shelves = assembleShelves(emptyFeed, [
      {
        source: "similar",
        seedTitle: "Past Lives",
        candidates: [candidate("1"), candidate("2"), candidate("3")]
      },
      {
        source: "trending",
        seedTitle: null,
        candidates: [candidate("1"), candidate("4"), candidate("5"), candidate("6")]
      }
    ]);
    expect(shelves[0].items).toHaveLength(3);
    // "1" was taken by the similar shelf, so trending is down to three.
    expect(shelves[1].items).toHaveLength(3);
  });

  it("orders shelves by tier, not by arrival", () => {
    const feed: RecommendationFeed = {
      ...emptyFeed,
      sections: [
        { source: "followed", items: [mediaRow("a", "A"), mediaRow("b", "B"), mediaRow("c", "C")] },
        {
          source: "taste_twins",
          items: [mediaRow("d", "D"), mediaRow("e", "E"), mediaRow("f", "F")]
        }
      ]
    };
    const shelves = assembleShelves(feed, [
      {
        source: "trending",
        seedTitle: null,
        candidates: [candidate("1"), candidate("2"), candidate("3")]
      }
    ]);
    expect(shelves.map((shelf) => shelf.source)).toEqual(["taste_twins", "followed", "trending"]);
  });

  it("keeps at most four shelves", () => {
    const many: CandidateShelf[] = ["1", "2", "3", "4", "5"].map((seed) => ({
      source: "similar" as const,
      seedTitle: `Seed ${seed}`,
      candidates: [candidate(`${seed}a`), candidate(`${seed}b`), candidate(`${seed}c`)]
    }));
    expect(assembleShelves(emptyFeed, many)).toHaveLength(4);
  });

  it("caps a shelf at twelve items", () => {
    const candidates = Array.from({ length: 30 }, (_, index) => candidate(`c${index}`));
    const shelves = assembleShelves(emptyFeed, [
      { source: "trending", seedTitle: null, candidates }
    ]);
    expect(shelves[0].items).toHaveLength(12);
  });

  it("carries the seed title so the shelf can name what it is like", () => {
    const shelves = assembleShelves(emptyFeed, [
      {
        source: "similar",
        seedTitle: "Past Lives",
        candidates: [candidate("1"), candidate("2"), candidate("3")]
      }
    ]);
    expect(shelves[0].seedTitle).toBe("Past Lives");
  });
});
```

- [ ] **Step 2: Run them and watch them fail**

```bash
export PATH="$HOME/.nvm/versions/node/v24.18.1/bin:$PATH"
cd /Users/charlessalomon/GitProjects/venn/web
npm run test -- recommendations
```

Expected: fails to resolve `@/lib/recommendations`.

- [ ] **Step 3: Write the module**

Create `web/lib/recommendations.ts`:

```ts
import { candidateId, type ExternalSource, type MediaCandidate } from "@/lib/catalog/types";
import { toMedia, type Media, type MediaKind, type MediaRow } from "@/lib/media";

/** Which tier a shelf came from. Ordered by how much venn knows about you. */
export type ShelfSource = "taste_twins" | "followed" | "similar" | "trending";

/** Tier order is fixed — see the spec's ladder. */
const TIER_ORDER: ShelfSource[] = ["taste_twins", "followed", "similar", "trending"];

/** A shelf below this reads as broken rather than as a recommendation. */
export const MIN_SHELF_ITEMS = 3;
/** More than this and Explorer becomes a wall of rows. */
export const MAX_SHELVES = 4;
export const MAX_SHELF_ITEMS = 12;

export interface ExcludedKey {
  source: ExternalSource;
  kind: MediaKind;
  id: string;
}

export interface Seed {
  media_id: string;
  title: string;
  kind: MediaKind;
  external_source: ExternalSource;
  external_id: string;
  rating: number;
}

export interface FeedSection {
  source: "taste_twins" | "followed";
  items: MediaRow[];
}

/** Exactly what `recommendation_feed()` returns. */
export interface RecommendationFeed {
  sections: FeedSection[];
  seeds: Seed[];
  excluded: ExcludedKey[];
}

/** A shelf's worth of catalog results, before filtering. */
export interface CandidateShelf {
  source: "similar" | "trending";
  /** The title this shelf is "more like". Null for trending. */
  seedTitle: string | null;
  candidates: MediaCandidate[];
}

/**
 * An item on a shelf. Rows from venn's own catalog are `Media` and can be
 * opened directly; catalog results are `MediaCandidate` and have to be
 * upserted before they can be. The UI treats them differently, so the
 * distinction is in the type rather than discovered at render time.
 */
export type ShelfItem =
  | { kind: "media"; media: Media }
  | { kind: "candidate"; candidate: MediaCandidate };

export interface Shelf {
  source: ShelfSource;
  seedTitle: string | null;
  items: ShelfItem[];
}

/**
 * Turn the RPC payload and whatever the catalogs returned into the shelves
 * to render.
 *
 * Pure by design: no network, no clock, no UI. This is the only logic that
 * exists on both platforms, so it is kept small enough to hold in your head
 * and tested with the same cases on each side.
 */
export function assembleShelves(
  feed: RecommendationFeed,
  candidateShelves: CandidateShelf[]
): Shelf[] {
  const excluded = new Set(feed.excluded.map((key) => candidateId(key.source, key.kind, key.id)));
  // Grows as shelves are built, so an item claimed by a higher tier cannot
  // reappear lower down.
  const claimed = new Set<string>();

  const fromSections: Shelf[] = feed.sections.map((section) => ({
    source: section.source,
    seedTitle: null,
    items: section.items.map((row) => ({
      kind: "media" as const,
      media: toMedia(row)
    }))
  }));

  const fromCandidates: Shelf[] = candidateShelves.map((shelf) => ({
    source: shelf.source,
    seedTitle: shelf.seedTitle,
    items: shelf.candidates.map((candidate) => ({
      kind: "candidate" as const,
      candidate
    }))
  }));

  const ordered = [...fromSections, ...fromCandidates].sort(
    (a, b) => TIER_ORDER.indexOf(a.source) - TIER_ORDER.indexOf(b.source)
  );

  const shelves: Shelf[] = [];
  for (const shelf of ordered) {
    if (shelves.length >= MAX_SHELVES) break;

    const items: ShelfItem[] = [];
    for (const item of shelf.items) {
      if (items.length >= MAX_SHELF_ITEMS) break;

      const key = itemKey(item);
      if (key === null) {
        // A hand-typed row has no catalog identity, so it can be neither
        // excluded nor deduped. Show it — it came from venn's own data.
        items.push(item);
        continue;
      }
      if (excluded.has(key) || claimed.has(key)) continue;

      claimed.add(key);
      items.push(item);
    }

    if (items.length >= MIN_SHELF_ITEMS) {
      shelves.push({ source: shelf.source, seedTitle: shelf.seedTitle, items });
    }
  }

  return shelves;
}

/** `"<source>:<kind>:<externalId>"`, or null when the item has no catalog identity. */
function itemKey(item: ShelfItem): string | null {
  if (item.kind === "candidate") return item.candidate.id;

  const { externalSource, externalId, kind } = item.media;
  if (!externalSource || !externalId) return null;
  return candidateId(externalSource, kind, externalId);
}
```

- [ ] **Step 4: Run them and watch them pass**

```bash
npm run test -- recommendations
npx tsc --noEmit
```

Expected: all pass, no type errors.

- [ ] **Step 5: Commit**

```bash
cd /Users/charlessalomon/GitProjects/venn
git add web/lib/recommendations.ts web/lib/__tests__/recommendations.test.ts
git commit -m "feat(web): add the recommendation shelf assembler

Pure function taking the RPC payload plus catalog results and returning
the shelves to render: exclusion, dedup across tiers, the three-item
floor and the four-shelf cap. This is the only logic that lives on both
platforms, so it is isolated and tested with the cases iOS will reuse."
```

---

### Task 4: Web — catalog similar and trending

**Files:**

- Create: `web/lib/catalog/similar.ts`
- Test: `web/lib/catalog/__tests__/similar.test.ts`

**Interfaces:**

- Consumes: `toMovieCandidates`, `toShowCandidates` from `@/lib/catalog/tmdb`; `toBookCandidates` from `@/lib/catalog/openLibrary`; `toAlbumCandidates` from `@/lib/catalog/musicBrainz`; `Seed` from `@/lib/recommendations`
- Produces:
  - `fetchSimilar(seed: Seed, apiKey: string | undefined): Promise<MediaCandidate[]>`
  - `fetchTrending(apiKey: string | undefined): Promise<MediaCandidate[]>`
  - `toTrendingCandidates(json: unknown): MediaCandidate[]`

- [ ] **Step 1: Write the failing tests**

Create `web/lib/catalog/__tests__/similar.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { toTrendingCandidates } from "@/lib/catalog/similar";

describe("toTrendingCandidates", () => {
  it("keeps movies and shows and labels each correctly", () => {
    // /trending/all/week mixes both, distinguished by media_type.
    const candidates = toTrendingCandidates({
      results: [
        { id: 1, media_type: "movie", title: "A Film", release_date: "2023-01-01" },
        { id: 2, media_type: "tv", name: "A Show", first_air_date: "2022-01-01" }
      ]
    });

    expect(candidates.map((candidate) => candidate.kind)).toEqual(["movie", "show"]);
    expect(candidates[0].id).toBe("tmdb:movie:1");
    expect(candidates[1].id).toBe("tmdb:show:2");
  });

  it("drops people, which that endpoint also returns", () => {
    // media_type "person" has no title and is not something you can log.
    const candidates = toTrendingCandidates({
      results: [
        { id: 3, media_type: "person", name: "Someone" },
        { id: 4, media_type: "movie", title: "A Film" }
      ]
    });

    expect(candidates).toHaveLength(1);
    expect(candidates[0].kind).toBe("movie");
  });

  it("survives a payload with no results", () => {
    expect(toTrendingCandidates({})).toEqual([]);
    expect(toTrendingCandidates(null)).toEqual([]);
  });
});
```

- [ ] **Step 2: Run and watch fail**

```bash
export PATH="$HOME/.nvm/versions/node/v24.18.1/bin:$PATH"
cd /Users/charlessalomon/GitProjects/venn/web
npm run test -- similar
```

Expected: cannot resolve `@/lib/catalog/similar`.

- [ ] **Step 3: Write the module**

Create `web/lib/catalog/similar.ts`:

```ts
import { toAlbumCandidates } from "@/lib/catalog/musicBrainz";
import { toBookCandidates } from "@/lib/catalog/openLibrary";
import { toMovieCandidates, toShowCandidates } from "@/lib/catalog/tmdb";
import { type MediaCandidate } from "@/lib/catalog/types";
import type { Seed } from "@/lib/recommendations";

const TMDB_BASE = "https://api.themoviedb.org/3";
const OPEN_LIBRARY_BASE = "https://openlibrary.org";
const MUSICBRAINZ_BASE = "https://musicbrainz.org/ws/2";
const USER_AGENT = "Venn/1.0 (social.venn.app)";

/** Catalog responses change slowly; an hour keeps Explorer snappy. */
const REVALIDATE_SECONDS = 3600;

async function getJson(url: string, headers: HeadersInit = {}): Promise<unknown> {
  const response = await fetch(url, { headers, next: { revalidate: REVALIDATE_SECONDS } });
  if (!response.ok) throw new Error(`Catalog request failed: ${response.status}`);
  return await response.json();
}

/**
 * Things like this seed.
 *
 * Film and TV get TMDB's own recommendations, which is real collaborative
 * filtering computed from millions of users — which is what makes this
 * feature work from a user's very first log rather than needing venn to
 * have scale first.
 *
 * Books and music have no equivalent. They fall back to the same author or
 * the same artist, and the shelf copy says so rather than implying a taste
 * match we cannot support.
 */
export async function fetchSimilar(
  seed: Seed,
  apiKey: string | undefined
): Promise<MediaCandidate[]> {
  if (seed.external_source === "tmdb") {
    if (!apiKey) return [];
    const path = seed.kind === "movie" ? "movie" : "tv";
    const json = await getJson(
      `${TMDB_BASE}/${path}/${seed.external_id}/recommendations?api_key=${apiKey}`
    );
    return seed.kind === "movie" ? toMovieCandidates(json) : toShowCandidates(json);
  }

  if (seed.external_source === "openlibrary") {
    const work = (await getJson(`${OPEN_LIBRARY_BASE}/works/${seed.external_id}.json`)) as {
      subjects?: string[];
    };
    const subject = work.subjects?.[0];
    if (!subject) return [];
    const json = await getJson(
      `${OPEN_LIBRARY_BASE}/subjects/${encodeURIComponent(
        subject.toLowerCase().replace(/\s+/g, "_")
      )}.json?limit=20`
    );
    return toBookCandidates(json);
  }

  const json = await getJson(
    `${MUSICBRAINZ_BASE}/release-group?release-group=${seed.external_id}&fmt=json&limit=20`,
    { "User-Agent": USER_AGENT }
  );
  return toAlbumCandidates(json);
}

interface TrendingResult {
  id?: number;
  media_type?: string;
  title?: string;
  name?: string;
  release_date?: string;
  first_air_date?: string;
}

/**
 * `/trending/all/week` returns movies, shows **and people** in one list.
 * People are not something you can log, so they are dropped rather than
 * rendered as a coverless card.
 */
export function toTrendingCandidates(json: unknown): MediaCandidate[] {
  const results = (json as { results?: TrendingResult[] } | null)?.results;
  if (!Array.isArray(results)) return [];

  const movies = results.filter((result) => result.media_type === "movie");
  const shows = results.filter((result) => result.media_type === "tv");

  return [...toMovieCandidates({ results: movies }), ...toShowCandidates({ results: shows })];
}

/** What is popular right now. The floor of the ladder — always available. */
export async function fetchTrending(apiKey: string | undefined): Promise<MediaCandidate[]> {
  if (!apiKey) return [];
  return toTrendingCandidates(await getJson(`${TMDB_BASE}/trending/all/week?api_key=${apiKey}`));
}
```

- [ ] **Step 4: Run and watch pass**

```bash
npm run test -- similar
npx tsc --noEmit
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/charlessalomon/GitProjects/venn
git add web/lib/catalog/similar.ts web/lib/catalog/__tests__/similar.test.ts
git commit -m "feat(web): fetch similar titles and trending from the catalogs

TMDB's per-title recommendations endpoint is real collaborative
filtering computed from millions of users, which is what lets venn
recommend from a user's first log instead of needing scale first. Books
and music have no equivalent and fall back to same-author and
same-artist, which the shelf copy states rather than implying a taste
match."
```

---

### Task 5: Web — the shelves, wired into Explorer

**Files:**

- Create: `web/components/RecommendationShelves.tsx`
- Create: `web/lib/recommendationCopy.ts`
- Test: `web/components/__tests__/RecommendationShelves.test.tsx`
- Modify: `web/components/Explorer.tsx`

**Interfaces:**

- Consumes: `Shelf`, `ShelfSource` from `@/lib/recommendations`
- Produces: `shelfTitle(shelf: Shelf): string`; `<RecommendationShelves shelves={...} />`

- [ ] **Step 1: Write the failing test**

Create `web/components/__tests__/RecommendationShelves.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { RecommendationShelves } from "@/components/RecommendationShelves";
import type { Shelf } from "@/lib/recommendations";

function candidateShelf(source: Shelf["source"], seedTitle: string | null): Shelf {
  return {
    source,
    seedTitle,
    items: ["1", "2", "3"].map((externalId) => ({
      kind: "candidate" as const,
      candidate: {
        id: `tmdb:movie:${externalId}`,
        title: `Title ${externalId}`,
        primaryCreator: null,
        year: null,
        coverUrl: null,
        overview: null,
        externalId,
        externalSource: "tmdb" as const,
        kind: "movie" as const
      }
    }))
  };
}

describe("RecommendationShelves", () => {
  it("names a similar shelf after the thing it is like", () => {
    render(<RecommendationShelves shelves={[candidateShelf("similar", "Past Lives")]} />);
    expect(screen.getByText("More like Past Lives")).toBeDefined();
  });

  it("labels each tier for what it actually is", () => {
    // The labels are the whole point of grouping: a trending shelf must not
    // read as a personal recommendation.
    render(
      <RecommendationShelves
        shelves={[candidateShelf("taste_twins", null), candidateShelf("trending", null)]}
      />
    );
    expect(screen.getByText("Popular with people who match your taste")).toBeDefined();
    expect(screen.getByText("Trending this week")).toBeDefined();
  });

  it("renders nothing at all when there are no shelves", () => {
    const { container } = render(<RecommendationShelves shelves={[]} />);
    expect(container.firstChild).toBeNull();
  });
});
```

- [ ] **Step 2: Run and watch fail**

```bash
export PATH="$HOME/.nvm/versions/node/v24.18.1/bin:$PATH"
cd /Users/charlessalomon/GitProjects/venn/web
npm run test -- RecommendationShelves
```

Expected: cannot resolve `@/components/RecommendationShelves`.

- [ ] **Step 3: Write the copy module**

Create `web/lib/recommendationCopy.ts`:

```ts
import type { Shelf } from "@/lib/recommendations";

/**
 * Shelf headings.
 *
 * Copy lives here rather than in SQL so that rule 17's parity check stays
 * in the clients, where it already is — the RPC returns a `source`
 * discriminator and nothing user-facing.
 *
 * Every label states what the shelf actually is. "Trending this week" is
 * not dressed up as a personal recommendation, and a books shelf built
 * from the same author says so rather than implying a taste match venn
 * cannot support.
 *
 * Mirrored by iOS's `RecommendationShelf.title` — keep them identical.
 */
export function shelfTitle(shelf: Shelf): string {
  switch (shelf.source) {
    case "taste_twins":
      return "Popular with people who match your taste";
    case "followed":
      return "Loved by people you follow";
    case "similar":
      return shelf.seedTitle ? `More like ${shelf.seedTitle}` : "More like what you loved";
    case "trending":
      return "Trending this week";
  }
}
```

- [ ] **Step 4: Write the component**

Create `web/components/RecommendationShelves.tsx`:

```tsx
import Link from "next/link";
import { MediaCover } from "@/components/MediaCover";
import { shelfTitle } from "@/lib/recommendationCopy";
import type { Shelf, ShelfItem } from "@/lib/recommendations";

interface RecommendationShelvesProps {
  shelves: Shelf[];
}

/**
 * The recommendation shelves, above Explorer's browse grid.
 *
 * Renders nothing when there are no shelves rather than an empty state:
 * the browse grid below is already a reasonable thing to look at, and a
 * "no recommendations yet" message would be noise on top of it.
 */
export function RecommendationShelves({ shelves }: RecommendationShelvesProps) {
  if (shelves.length === 0) return null;

  return (
    <div className="flex flex-col gap-6">
      {shelves.map((shelf) => (
        <section key={`${shelf.source}-${shelf.seedTitle ?? ""}`} className="flex flex-col gap-2">
          <h2 className="font-semibold text-(--color-text-primary)">{shelfTitle(shelf)}</h2>
          <ul className="flex gap-3 overflow-x-auto pb-1">
            {shelf.items.map((item) => (
              <li key={itemKey(item)} className="w-[110px] shrink-0">
                <ShelfCard item={item} />
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}

/**
 * A catalog result is not in `public.media` yet, so it has no detail page
 * to open — it goes to the composer prefilled instead, which is also the
 * action someone wants after seeing something they like.
 */
function ShelfCard({ item }: { item: ShelfItem }) {
  if (item.kind === "media") {
    return (
      <Link href={`/media/${item.media.id}`} className="flex flex-col gap-1">
        <MediaCover media={item.media} />
        <span className="line-clamp-2 text-xs text-(--color-text-secondary)">
          {item.media.title}
        </span>
      </Link>
    );
  }

  const { candidate } = item;
  return (
    <Link
      href={`/composer?kind=${candidate.kind}&q=${encodeURIComponent(candidate.title)}`}
      className="flex flex-col gap-1"
    >
      <div className="flex h-[165px] items-center justify-center overflow-hidden rounded-md bg-(--color-surface-strong)">
        {candidate.coverUrl ? (
          // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
          <img
            src={candidate.coverUrl}
            alt=""
            loading="lazy"
            className="h-full w-full object-cover"
          />
        ) : (
          <span className="px-2 text-center text-xs text-(--color-text-secondary)">
            {candidate.title}
          </span>
        )}
      </div>
      <span className="line-clamp-2 text-xs text-(--color-text-secondary)">{candidate.title}</span>
    </Link>
  );
}

function itemKey(item: ShelfItem): string {
  return item.kind === "media" ? item.media.id : item.candidate.id;
}
```

- [ ] **Step 5: Run and watch pass**

```bash
npm run test -- RecommendationShelves
npx tsc --noEmit
```

Expected: all pass.

- [ ] **Step 6: Wire into Explorer**

In `web/components/Explorer.tsx`, add to the imports:

```tsx
import { RecommendationShelves } from "@/components/RecommendationShelves";
import type { Shelf } from "@/lib/recommendations";
```

Add `shelves` to `ExplorerProps` (the component already receives props from its page):

```tsx
  /** Recommendation shelves, fetched on the server. Empty renders nothing. */
  shelves?: Shelf[];
```

Then render them immediately after the search input and before the category chips' results, inside the top-level `<div className="flex flex-col gap-4">`:

```tsx
{
  trimmed.length === 0 && shelves && shelves.length > 0 && (
    <RecommendationShelves shelves={shelves} />
  );
}
```

The `trimmed.length === 0` guard matters: shelves are for browsing, and leaving them above live search results would push the thing the user just typed off the screen.

- [ ] **Step 7: Fetch them in the Explorer page**

In `web/app/(app)/explorer/page.tsx`, before rendering `<Explorer />`:

```tsx
import { assembleShelves, type RecommendationFeed } from "@/lib/recommendations";
import { fetchSimilar, fetchTrending } from "@/lib/catalog/similar";

// …inside the page component, after the auth check:

// Recommendations are decoration relative to search: if any of this
// fails, Explorer still works. So every branch degrades to fewer
// shelves rather than to an error.
let shelves: Shelf[] = [];
try {
  const { data } = await supabase.rpc("recommendation_feed");
  const feed = (data ?? { sections: [], seeds: [], excluded: [] }) as RecommendationFeed;
  const apiKey = process.env.TMDB_API_KEY;

  const settled = await Promise.allSettled([
    ...feed.seeds.map((seed) => fetchSimilar(seed, apiKey)),
    fetchTrending(apiKey)
  ]);

  const candidateShelves = settled.map((result, index) => ({
    source: (index < feed.seeds.length ? "similar" : "trending") as "similar" | "trending",
    seedTitle: index < feed.seeds.length ? feed.seeds[index].title : null,
    candidates: result.status === "fulfilled" ? result.value : []
  }));

  shelves = assembleShelves(feed, candidateShelves);
} catch {
  shelves = [];
}
```

Then pass `shelves={shelves}` to `<Explorer />`.

`Promise.allSettled` rather than `Promise.all` is the point: one provider being down should cost one shelf, not all of them.

- [ ] **Step 8: Verify the whole web suite**

```bash
npm run test
npx tsc --noEmit
npm run lint
```

Expected: all pass.

- [ ] **Step 9: Commit**

```bash
cd /Users/charlessalomon/GitProjects/venn
git add web/components/RecommendationShelves.tsx web/lib/recommendationCopy.ts \
  web/components/__tests__/RecommendationShelves.test.tsx \
  "web/components/Explorer.tsx" "web/app/(app)/explorer/page.tsx"
git commit -m "feat(web): show recommendation shelves in Explorer

Shelves render above the browse grid and only when the search box is
empty — leaving them above live results would push what the user just
typed off screen. Each provider is fetched with allSettled so one being
down costs one shelf rather than all of them."
```

---

### Task 6: iOS — the service and its models

**Files:**

- Create: `ios/Venn/Features/Explorer/Recommendations/RecommendationService.swift`
- Test: `ios/VennTests/Features/Explorer/RecommendationServiceTests.swift`

**Interfaces:**

- Produces:
  - `enum ShelfSource: String { case tasteTwins = "taste_twins", followed, similar, trending }`
  - `struct RecommendationSeed: Equatable, Sendable` — `mediaID: UUID, title: String, kind: MediaKind, externalSource: ExternalSource, externalID: String, rating: Double`
  - `struct ExcludedKey: Hashable, Sendable` — `source: ExternalSource, kind: MediaKind, id: String`, with `var key: String`
  - `struct RecommendationFeed: Equatable, Sendable` — `sections: [FeedSection], seeds: [RecommendationSeed], excluded: [ExcludedKey]`
  - `struct FeedSection: Equatable, Sendable` — `source: ShelfSource, items: [Media]`
  - `protocol RecommendationServicing: Sendable { func feed() async throws -> RecommendationFeed }`
  - `struct RecommendationService: RecommendationServicing`

- [ ] **Step 1: Write the failing test**

Create `ios/VennTests/Features/Explorer/RecommendationServiceTests.swift`:

```swift
import Foundation
import Testing
@testable import Venn

/// Decoding the RPC payload, and the exclusion key's exact format — which
/// is a cross-platform contract, not an implementation detail.
struct RecommendationServiceTests {
    @Test
    func exclusionKeyMatchesTheFormatWebUses() {
        // web/lib/catalog/types.ts candidateId() builds the same string.
        let key = ExcludedKey(source: .tmdb, kind: .movie, id: "666277")
        #expect(key.key == "tmdb:movie:666277")
    }

    @Test
    func kindIsPartOfTheExclusionKey() {
        // Excluding the movie must not hide the show with the same number.
        let movie = ExcludedKey(source: .tmdb, kind: .movie, id: "5")
        let show = ExcludedKey(source: .tmdb, kind: .show, id: "5")
        #expect(movie.key != show.key)
    }

    @Test
    func decodesAnEmptyFeed() throws {
        // A brand-new user gets exactly this, and it is not an error.
        let json = Data(#"{"sections":[],"seeds":[],"excluded":[]}"#.utf8)
        let feed = try JSONDecoder().decode(RecommendationFeed.self, from: json)

        #expect(feed.sections.isEmpty)
        #expect(feed.seeds.isEmpty)
        #expect(feed.excluded.isEmpty)
    }

    @Test
    func decodesSeedsAndExclusions() throws {
        let json = Data(#"""
        {
          "sections": [],
          "seeds": [{
            "media_id": "22222222-2222-2222-2222-222222222222",
            "title": "Past Lives", "kind": "movie",
            "external_source": "tmdb", "external_id": "666277", "rating": 5.0
          }],
          "excluded": [{ "source": "tmdb", "kind": "movie", "id": "666277" }]
        }
        """#.utf8)
        let feed = try JSONDecoder().decode(RecommendationFeed.self, from: json)

        #expect(feed.seeds.first?.title == "Past Lives")
        #expect(feed.seeds.first?.externalSource == .tmdb)
        #expect(feed.excluded.first?.key == "tmdb:movie:666277")
    }

    @Test
    func dropsASectionWithAnUnknownSource() throws {
        // A future tier added server-side must not crash an older client.
        let json = Data(#"""
        {"sections":[{"source":"quantum","items":[]}],"seeds":[],"excluded":[]}
        """#.utf8)
        let feed = try JSONDecoder().decode(RecommendationFeed.self, from: json)

        #expect(feed.sections.isEmpty)
    }
}
```

- [ ] **Step 2: Run and watch fail**

```bash
cd /Users/charlessalomon/GitProjects/venn
make project
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData build-for-testing 2>&1 | grep -E "error:" | sort -u
```

Expected: `cannot find 'ExcludedKey' in scope`.

- [ ] **Step 3: Write the service**

Create `ios/Venn/Features/Explorer/Recommendations/RecommendationService.swift`:

```swift
import Foundation
import Supabase

/// Which tier a shelf came from. Ordered by how much venn knows about you.
enum ShelfSource: String, Codable, Sendable {
    case tasteTwins = "taste_twins"
    case followed
    case similar
    case trending
}

/// Something the viewer loved, used to ask a catalog for more like it.
struct RecommendationSeed: Equatable, Sendable, Decodable {
    let mediaID: UUID
    let title: String
    let kind: MediaKind
    let externalSource: ExternalSource
    let externalID: String
    let rating: Double

    enum CodingKeys: String, CodingKey {
        case title, kind, rating
        case mediaID = "media_id"
        case externalSource = "external_source"
        case externalID = "external_id"
    }
}

/// A catalog item the viewer has already dealt with.
struct ExcludedKey: Hashable, Sendable, Decodable {
    let source: ExternalSource
    let kind: MediaKind
    let id: String

    /// `"<source>:<kind>:<id>"` — byte-identical to web's `candidateId()`
    /// and to `MediaCandidate.id`. Kind is load-bearing: TMDB numbers
    /// movies and TV independently.
    var key: String {
        "\(source.rawValue):\(kind.rawValue):\(id)"
    }
}

/// One tier that came straight from venn's own data.
struct FeedSection: Equatable, Sendable {
    let source: ShelfSource
    let items: [Media]
}

/// Exactly what `recommendation_feed()` returns.
struct RecommendationFeed: Equatable, Sendable, Decodable {
    let sections: [FeedSection]
    let seeds: [RecommendationSeed]
    let excluded: [ExcludedKey]

    static let empty = RecommendationFeed(sections: [], seeds: [], excluded: [])

    init(sections: [FeedSection], seeds: [RecommendationSeed], excluded: [ExcludedKey]) {
        self.sections = sections
        self.seeds = seeds
        self.excluded = excluded
    }

    private struct RawSection: Decodable {
        let source: String
        let items: [MediaSchema.Row]
    }

    private enum CodingKeys: String, CodingKey {
        case sections, seeds, excluded
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        seeds = try container.decodeIfPresent([RecommendationSeed].self, forKey: .seeds) ?? []
        excluded = try container.decodeIfPresent([ExcludedKey].self, forKey: .excluded) ?? []

        // A tier added server-side ahead of a client release is dropped
        // rather than crashing an older app.
        let raw = try container.decodeIfPresent([RawSection].self, forKey: .sections) ?? []
        sections = raw.compactMap { section in
            guard let source = ShelfSource(rawValue: section.source) else { return nil }
            return FeedSection(source: source, items: section.items.compactMap(Media.init(row:)))
        }
    }
}

/// Behind a protocol so the view-model unit-tests with a fake (ADR 0005).
protocol RecommendationServicing: Sendable {
    func feed() async throws -> RecommendationFeed
}

/// Production implementation. Funnels errors through `AppError.from(_:)`
/// so callers see one semantic error type (ADR 0006).
struct RecommendationService: RecommendationServicing {
    let client: SupabaseClient

    func feed() async throws -> RecommendationFeed {
        do {
            return try await client
                .rpc("recommendation_feed")
                .execute()
                .value
        } catch {
            throw AppError.from(error)
        }
    }
}
```

- [ ] **Step 4: Run and watch pass**

```bash
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData build-for-testing 2>&1 | tail -3
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData -only-testing:VennTests test-without-building 2>&1 \
  | grep -E "✘|Test run with"
```

Expected: `TEST BUILD SUCCEEDED`, then all tests pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Venn/Features/Explorer/Recommendations/RecommendationService.swift \
  ios/VennTests/Features/Explorer/RecommendationServiceTests.swift
git commit -m "feat(ios): add the recommendation feed service

Decodes the RPC payload. A tier added server-side ahead of a client
release is dropped rather than crashing an older app, and the exclusion
key is asserted against the exact string web builds, because that format
is a cross-platform contract."
```

---

### Task 7: iOS — the pure assembler

The same rules as Task 3, tested with the same cases. If these two ever disagree, the platforms have drifted.

**Files:**

- Create: `ios/Venn/Features/Explorer/Recommendations/RecommendationAssembler.swift`
- Test: `ios/VennTests/Features/Explorer/RecommendationAssemblerTests.swift`

**Interfaces:**

- Consumes: `RecommendationFeed`, `ShelfSource`, `ExcludedKey` from Task 6
- Produces:
  - `enum ShelfItem: Identifiable, Equatable, Sendable { case media(Media), candidate(MediaCandidate) }`
  - `struct RecommendationShelf: Identifiable, Equatable, Sendable { let source: ShelfSource; let seedTitle: String?; let items: [ShelfItem]; var title: String }`
  - `struct CandidateShelf: Equatable, Sendable { let source: ShelfSource; let seedTitle: String?; let candidates: [MediaCandidate] }`
  - `enum RecommendationAssembler { static func assembleShelves(feed:candidateShelves:) -> [RecommendationShelf] }`
  - `RecommendationAssembler.minShelfItems = 3`, `.maxShelves = 4`, `.maxShelfItems = 12`

- [ ] **Step 1: Write the failing tests**

Create `ios/VennTests/Features/Explorer/RecommendationAssemblerTests.swift`:

```swift
import Foundation
import Testing
@testable import Venn

/// The same cases as web's `recommendations.test.ts`. This function is the
/// only logic that exists on both platforms; if these two suites ever
/// disagree, the platforms have drifted.
struct RecommendationAssemblerTests {
    private static func candidate(
        _ externalID: String,
        kind: MediaKind = .movie
    ) -> MediaCandidate {
        MediaCandidate(
            title: "Title \(externalID)",
            primaryCreator: nil,
            year: nil,
            coverURL: nil,
            overview: nil,
            externalID: externalID,
            externalSource: .tmdb,
            kind: kind
        )
    }

    private static func media(_ index: Int) -> Media {
        Media(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index)) ?? UUID(),
            kind: .movie,
            title: "Media \(index)",
            year: nil,
            primaryCreator: nil,
            coverURL: nil,
            externalID: nil,
            externalSource: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    private static func shelf(
        _ source: ShelfSource,
        seedTitle: String? = nil,
        _ ids: [String]
    ) -> CandidateShelf {
        CandidateShelf(
            source: source,
            seedTitle: seedTitle,
            candidates: ids.map { candidate($0) }
        )
    }

    @Test
    func returnsNothingWhenThereIsNothing() {
        #expect(RecommendationAssembler.assembleShelves(
            feed: .empty, candidateShelves: []
        ).isEmpty)
    }

    @Test
    func dropsAShelfWithFewerThanThreeItems() {
        // Two covers under a heading reads as broken, not as a recommendation.
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [Self.shelf(.trending, ["1", "2"])]
        )
        #expect(shelves.isEmpty)
    }

    @Test
    func keepsAShelfWithExactlyThree() {
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [Self.shelf(.trending, ["1", "2", "3"])]
        )
        #expect(shelves.count == 1)
        #expect(shelves[0].items.count == 3)
    }

    @Test
    func neverShowsSomethingTheViewerHasAlreadySeen() {
        let feed = RecommendationFeed(
            sections: [],
            seeds: [],
            excluded: [ExcludedKey(source: .tmdb, kind: .movie, id: "2")]
        )
        let shelves = RecommendationAssembler.assembleShelves(
            feed: feed,
            candidateShelves: [Self.shelf(.trending, ["1", "2", "3", "4"])]
        )

        #expect(shelves[0].items.count == 3)
        #expect(!shelves[0].items.contains { $0.id == "tmdb:movie:2" })
    }

    @Test
    func excludesOnKindAsWellAsID() {
        // TMDB movie 5 and show 5 are different things; excluding the movie
        // must not hide the show.
        let feed = RecommendationFeed(
            sections: [],
            seeds: [],
            excluded: [ExcludedKey(source: .tmdb, kind: .movie, id: "5")]
        )
        let shelves = RecommendationAssembler.assembleShelves(
            feed: feed,
            candidateShelves: [CandidateShelf(
                source: .trending,
                seedTitle: nil,
                candidates: [
                    Self.candidate("5", kind: .show),
                    Self.candidate("6"),
                    Self.candidate("7"),
                ]
            )]
        )

        #expect(shelves[0].items.count == 3)
    }

    @Test
    func showsAnItemOnceInTheHighestTierThatHasIt() {
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [
                Self.shelf(.similar, seedTitle: "Past Lives", ["1", "2", "3"]),
                Self.shelf(.trending, ["1", "4", "5", "6"]),
            ]
        )

        #expect(shelves[0].items.count == 3)
        #expect(shelves[1].items.count == 3)
    }

    @Test
    func ordersShelvesByTierNotByArrival() {
        let feed = RecommendationFeed(
            sections: [
                FeedSection(source: .followed, items: [Self.media(1), Self.media(2), Self.media(3)]),
                FeedSection(
                    source: .tasteTwins,
                    items: [Self.media(4), Self.media(5), Self.media(6)]
                ),
            ],
            seeds: [],
            excluded: []
        )
        let shelves = RecommendationAssembler.assembleShelves(
            feed: feed,
            candidateShelves: [Self.shelf(.trending, ["1", "2", "3"])]
        )

        #expect(shelves.map(\.source) == [.tasteTwins, .followed, .trending])
    }

    @Test
    func keepsAtMostFourShelves() {
        let many = (1...5).map { seed in
            Self.shelf(.similar, seedTitle: "Seed \(seed)", ["\(seed)a", "\(seed)b", "\(seed)c"])
        }

        #expect(RecommendationAssembler.assembleShelves(
            feed: .empty, candidateShelves: many
        ).count == 4)
    }

    @Test
    func capsAShelfAtTwelveItems() {
        let ids = (0..<30).map { "c\($0)" }
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [Self.shelf(.trending, ids)]
        )

        #expect(shelves[0].items.count == 12)
    }

    @Test
    func carriesTheSeedTitleSoTheShelfCanNameWhatItIsLike() {
        let shelves = RecommendationAssembler.assembleShelves(
            feed: .empty,
            candidateShelves: [Self.shelf(.similar, seedTitle: "Past Lives", ["1", "2", "3"])]
        )

        #expect(shelves[0].title == "More like Past Lives")
    }
}
```

- [ ] **Step 2: Run and watch fail**

```bash
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData build-for-testing 2>&1 | grep -E "error:" | sort -u
```

Expected: `cannot find 'RecommendationAssembler' in scope`.

- [ ] **Step 3: Write the assembler**

Create `ios/Venn/Features/Explorer/Recommendations/RecommendationAssembler.swift`:

```swift
import Foundation

/// One thing on a shelf.
///
/// Rows from venn's own catalog can be opened directly; catalog results
/// have to be upserted into `public.media` first, so they open the
/// composer instead. The distinction is in the type rather than discovered
/// at render time.
enum ShelfItem: Identifiable, Equatable, Sendable {
    case media(Media)
    case candidate(MediaCandidate)

    /// `"<source>:<kind>:<externalId>"` where there is a catalog identity.
    /// Falls back to the row's UUID for a hand-typed entry, which can be
    /// neither excluded nor deduped — there is nothing to compare.
    var id: String {
        switch self {
        case let .candidate(candidate):
            candidate.id
        case let .media(media):
            if let source = media.externalSource, let externalID = media.externalID {
                "\(source.rawValue):\(media.kind.rawValue):\(externalID)"
            } else {
                media.id.uuidString
            }
        }
    }

    /// True when `id` is a cross-platform catalog key rather than a local
    /// UUID standing in for one.
    var hasCatalogIdentity: Bool {
        switch self {
        case .candidate: true
        case let .media(media): media.externalSource != nil && media.externalID != nil
        }
    }

    var title: String {
        switch self {
        case let .media(media): media.title
        case let .candidate(candidate): candidate.title
        }
    }
}

/// A shelf, ready to render.
struct RecommendationShelf: Identifiable, Equatable, Sendable {
    let source: ShelfSource
    /// The title this shelf is "more like". Nil for every other tier.
    let seedTitle: String?
    let items: [ShelfItem]

    var id: String {
        "\(source.rawValue):\(seedTitle ?? "")"
    }

    /// Shelf heading.
    ///
    /// Mirrors web's `shelfTitle()` exactly (CLAUDE.md rule 17). Every
    /// label states what the shelf actually is — trending is not dressed up
    /// as a personal recommendation.
    var title: String {
        switch source {
        case .tasteTwins: "Popular with people who match your taste"
        case .followed: "Loved by people you follow"
        case .similar: seedTitle.map { "More like \($0)" } ?? "More like what you loved"
        case .trending: "Trending this week"
        }
    }
}

/// A shelf's worth of catalog results, before filtering.
struct CandidateShelf: Equatable, Sendable {
    let source: ShelfSource
    let seedTitle: String?
    let candidates: [MediaCandidate]
}

/// Turns the RPC payload and whatever the catalogs returned into the
/// shelves to render.
///
/// Pure by design: no network, no clock, no UI. This is the only logic
/// that exists on both platforms, so it is kept small enough to hold in
/// your head and tested with the same cases as web's `assembleShelves`.
enum RecommendationAssembler {
    /// Below this a shelf reads as broken rather than as a recommendation.
    static let minShelfItems = 3
    /// More than this and Explorer becomes a wall of rows.
    static let maxShelves = 4
    static let maxShelfItems = 12

    /// Tier order is fixed — see the spec's ladder.
    private static let tierOrder: [ShelfSource] = [.tasteTwins, .followed, .similar, .trending]

    static func assembleShelves(
        feed: RecommendationFeed,
        candidateShelves: [CandidateShelf]
    ) -> [RecommendationShelf] {
        let excluded = Set(feed.excluded.map(\.key))
        // Grows as shelves are built, so an item claimed by a higher tier
        // cannot reappear lower down.
        var claimed = Set<String>()

        let fromSections = feed.sections.map { section in
            RecommendationShelf(
                source: section.source,
                seedTitle: nil,
                items: section.items.map(ShelfItem.media)
            )
        }
        let fromCandidates = candidateShelves.map { shelf in
            RecommendationShelf(
                source: shelf.source,
                seedTitle: shelf.seedTitle,
                items: shelf.candidates.map(ShelfItem.candidate)
            )
        }

        let ordered = (fromSections + fromCandidates).sorted { left, right in
            (tierOrder.firstIndex(of: left.source) ?? tierOrder.count)
                < (tierOrder.firstIndex(of: right.source) ?? tierOrder.count)
        }

        var shelves: [RecommendationShelf] = []
        for shelf in ordered {
            if shelves.count >= maxShelves { break }

            var items: [ShelfItem] = []
            for item in shelf.items {
                if items.count >= maxShelfItems { break }

                if item.hasCatalogIdentity {
                    if excluded.contains(item.id) || claimed.contains(item.id) { continue }
                    claimed.insert(item.id)
                }
                items.append(item)
            }

            if items.count >= minShelfItems {
                shelves.append(RecommendationShelf(
                    source: shelf.source,
                    seedTitle: shelf.seedTitle,
                    items: items
                ))
            }
        }

        return shelves
    }
}
```

- [ ] **Step 4: Run and watch pass**

```bash
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData build-for-testing 2>&1 | tail -3
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData -only-testing:VennTests test-without-building 2>&1 \
  | grep -E "✘|Test run with"
```

Expected: all pass.

- [ ] **Step 5: Check the two suites agree**

Read `web/lib/__tests__/recommendations.test.ts` and `ios/VennTests/Features/Explorer/RecommendationAssemblerTests.swift` side by side. Every test in one must have a counterpart in the other. If one has a case the other lacks, add it — that gap is exactly where the platforms will drift.

- [ ] **Step 6: Commit**

```bash
git add ios/Venn/Features/Explorer/Recommendations/RecommendationAssembler.swift \
  ios/VennTests/Features/Explorer/RecommendationAssemblerTests.swift
git commit -m "feat(ios): add the recommendation shelf assembler

Same rules and the same test cases as web's assembleShelves: exclusion,
dedup across tiers, the three-item floor, the four-shelf cap. Pure, so
the one piece of logic living on both platforms is also the one most
thoroughly tested."
```

---

### Task 8: iOS — catalog similar and trending

**Files:**

- Create: `ios/Venn/Features/Explorer/Recommendations/CatalogSimilarService.swift`
- Test: `ios/VennTests/Features/Explorer/CatalogSimilarServiceTests.swift`

**Interfaces:**

- Consumes: `ExternalAPI.fetch(url:session:userAgent:)` from `ios/Venn/Services/Catalog/ExternalAPI.swift`; `RecommendationSeed` from Task 6
- Produces:
  - `protocol CatalogSimilarServicing: Sendable { func similar(to seed: RecommendationSeed) async throws -> [MediaCandidate]; func trending() async throws -> [MediaCandidate] }`
  - `struct CatalogSimilarService: CatalogSimilarServicing` — `init(tmdbAPIKey: String?, session: URLSession = .shared)`
  - `static func trendingCandidates(from data: Data) throws -> [MediaCandidate]`

- [ ] **Step 1: Write the failing test**

Create `ios/VennTests/Features/Explorer/CatalogSimilarServiceTests.swift`:

```swift
import Foundation
import Testing
@testable import Venn

/// Mapping only. Mirrors web's `similar.test.ts`.
struct CatalogSimilarServiceTests {
    @Test
    func keepsMoviesAndShowsAndLabelsEachCorrectly() throws {
        // /trending/all/week mixes both, distinguished by media_type.
        let json = Data(#"""
        {"results":[
          {"id":1,"media_type":"movie","title":"A Film","release_date":"2023-01-01"},
          {"id":2,"media_type":"tv","name":"A Show","first_air_date":"2022-01-01"}
        ]}
        """#.utf8)

        let candidates = try CatalogSimilarService.trendingCandidates(from: json)

        #expect(candidates.map(\.kind) == [.movie, .show])
        #expect(candidates[0].id == "tmdb:movie:1")
        #expect(candidates[1].id == "tmdb:show:2")
    }

    @Test
    func dropsPeopleWhichThatEndpointAlsoReturns() throws {
        // media_type "person" has no title and is not something you can log.
        let json = Data(#"""
        {"results":[
          {"id":3,"media_type":"person","name":"Someone"},
          {"id":4,"media_type":"movie","title":"A Film"}
        ]}
        """#.utf8)

        let candidates = try CatalogSimilarService.trendingCandidates(from: json)

        #expect(candidates.count == 1)
        #expect(candidates[0].kind == .movie)
    }

    @Test
    func survivesAPayloadWithNoResults() throws {
        #expect(try CatalogSimilarService.trendingCandidates(from: Data("{}".utf8)).isEmpty)
    }
}
```

- [ ] **Step 2: Run and watch fail**

```bash
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData build-for-testing 2>&1 | grep -E "error:" | sort -u
```

Expected: `cannot find 'CatalogSimilarService' in scope`.

- [ ] **Step 3: Write the service**

Create `ios/Venn/Features/Explorer/Recommendations/CatalogSimilarService.swift`:

```swift
import Foundation

/// Behind a protocol so the view-model unit-tests with a fake (ADR 0005).
protocol CatalogSimilarServicing: Sendable {
    func similar(to seed: RecommendationSeed) async throws -> [MediaCandidate]
    func trending() async throws -> [MediaCandidate]
}

/// Things like what you loved, and what is popular now.
///
/// Film and TV get TMDB's own recommendations — real collaborative
/// filtering computed from millions of users, which is what lets venn
/// recommend from a user's first log instead of needing scale first.
/// Books and music have no equivalent and fall back to the same subject or
/// the same artist; the shelf copy says so rather than implying a taste
/// match we cannot support.
struct CatalogSimilarService: CatalogSimilarServicing {
    private static let tmdbBase = "https://api.themoviedb.org/3"
    private static let openLibraryBase = "https://openlibrary.org"
    private static let musicBrainzBase = "https://musicbrainz.org/ws/2"
    private static let userAgent = "Venn/1.0 (social.venn.app)"

    private let tmdbAPIKey: String?
    private let session: URLSession

    init(tmdbAPIKey: String?, session: URLSession = .shared) {
        self.tmdbAPIKey = tmdbAPIKey
        self.session = session
    }

    func similar(to seed: RecommendationSeed) async throws -> [MediaCandidate] {
        switch seed.externalSource {
        case .tmdb:
            guard let tmdbAPIKey, !tmdbAPIKey.isEmpty else { return [] }
            let path = seed.kind == .movie ? "movie" : "tv"
            let raw = "\(Self.tmdbBase)/\(path)/\(seed.externalID)/recommendations?api_key=\(tmdbAPIKey)"
            guard let url = URL(string: raw) else { return [] }
            let data = try await ExternalAPI.fetch(url: url, session: session)
            return try Self.tmdbCandidates(from: data, kind: seed.kind)

        case .openlibrary:
            // Two calls: the work to find a subject, then that subject's
            // other books. OpenLibrary has no "similar" endpoint at all.
            guard let workURL = URL(
                string: "\(Self.openLibraryBase)/works/\(seed.externalID).json"
            ) else { return [] }
            let workData = try await ExternalAPI.fetch(url: workURL, session: session)
            guard let subject = try JSONDecoder()
                .decode(OLWorkSubjects.self, from: workData)
                .subjects?.first
            else { return [] }

            let slug = subject.lowercased().replacingOccurrences(of: " ", with: "_")
            guard let encoded = slug.addingPercentEncoding(
                withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "_-"))
            ),
                let subjectURL = URL(
                    string: "\(Self.openLibraryBase)/subjects/\(encoded).json?limit=20"
                )
            else { return [] }
            let subjectData = try await ExternalAPI.fetch(url: subjectURL, session: session)
            return try Self.bookCandidates(from: subjectData)

        case .musicbrainz:
            // Two calls again: the release-group to find its artist, then
            // that artist's other release-groups.
            guard let groupURL = URL(
                string: "\(Self.musicBrainzBase)/release-group/\(seed.externalID)?inc=artists&fmt=json"
            ) else { return [] }
            let groupData = try await ExternalAPI.fetch(
                url: groupURL, session: session, userAgent: Self.userAgent
            )
            guard let artistID = try JSONDecoder()
                .decode(MBGroupWithArtist.self, from: groupData)
                .artistCredit?.first?.artist?.id
            else { return [] }

            guard let browseURL = URL(
                string: "\(Self.musicBrainzBase)/release-group?artist=\(artistID)&fmt=json&limit=20"
            ) else { return [] }
            let browseData = try await ExternalAPI.fetch(
                url: browseURL, session: session, userAgent: Self.userAgent
            )
            let browsed = try JSONDecoder().decode(MBBrowseResponse.self, from: browseData)
            // Drop the seed itself — "more from this artist" should not
            // lead with the album you just rated.
            return browsed.releaseGroups
                .filter { $0.id != seed.externalID }
                .map(MusicBrainzService.candidate(from:))
        }
    }

    func trending() async throws -> [MediaCandidate] {
        guard let tmdbAPIKey, !tmdbAPIKey.isEmpty else { return [] }
        guard let url = URL(string: "\(Self.tmdbBase)/trending/all/week?api_key=\(tmdbAPIKey)")
        else { return [] }
        let data = try await ExternalAPI.fetch(url: url, session: session)
        return try Self.trendingCandidates(from: data)
    }

    // MARK: - Mapping

    private struct TrendingResponse: Decodable {
        let results: [TrendingResult]?
    }

    private struct TrendingResult: Decodable {
        let id: Int?
        let mediaType: String?
        let title: String?
        let name: String?
        let releaseDate: String?
        let firstAirDate: String?
        let posterPath: String?
        let overview: String?

        enum CodingKeys: String, CodingKey {
            case id, title, name, overview
            case mediaType = "media_type"
            case releaseDate = "release_date"
            case firstAirDate = "first_air_date"
            case posterPath = "poster_path"
        }
    }

    /// `/trending/all/week` returns movies, shows **and people** in one
    /// list. People are not something you can log, so they are dropped
    /// rather than rendered as a coverless card.
    static func trendingCandidates(from data: Data) throws -> [MediaCandidate] {
        let response = try JSONDecoder().decode(TrendingResponse.self, from: data)
        return (response.results ?? []).compactMap { result in
            guard let id = result.id else { return nil }
            let kind: MediaKind
            switch result.mediaType {
            case "movie": kind = .movie
            case "tv": kind = .show
            default: return nil
            }
            guard let title = result.title ?? result.name else { return nil }

            return MediaCandidate(
                title: title,
                primaryCreator: nil,
                year: ExternalAPI.year(from: result.releaseDate ?? result.firstAirDate),
                coverURL: result.posterPath.flatMap {
                    URL(string: "https://image.tmdb.org/t/p/w500\($0)")
                },
                overview: result.overview,
                externalID: String(id),
                externalSource: .tmdb,
                kind: kind
            )
        }
    }

    private static func tmdbCandidates(from data: Data, kind: MediaKind) throws -> [MediaCandidate] {
        // The /recommendations payload has the same shape as /trending
        // minus media_type, so reuse the decoder and supply the kind.
        let response = try JSONDecoder().decode(TrendingResponse.self, from: data)
        return (response.results ?? []).compactMap { result in
            guard let id = result.id, let title = result.title ?? result.name else { return nil }
            return MediaCandidate(
                title: title,
                primaryCreator: nil,
                year: ExternalAPI.year(from: result.releaseDate ?? result.firstAirDate),
                coverURL: result.posterPath.flatMap {
                    URL(string: "https://image.tmdb.org/t/p/w500\($0)")
                },
                overview: result.overview,
                externalID: String(id),
                externalSource: .tmdb,
                kind: kind
            )
        }
    }

    // MARK: - OpenLibrary wire format

    private struct OLWorkSubjects: Decodable {
        let subjects: [String]?
    }

    /// The `/subjects/{name}.json` payload, which is a different shape from
    /// search — `works` rather than `docs`, `cover_id` rather than `cover_i`
    /// — so `OpenLibraryService`'s search mapper cannot decode it.
    private struct OLSubjectResponse: Decodable {
        let works: [OLSubjectWork]?
    }

    private struct OLSubjectWork: Decodable {
        let key: String
        let title: String
        let authors: [OLSubjectAuthor]?
        let firstPublishYear: Int?
        let coverID: Int?

        enum CodingKeys: String, CodingKey {
            case key, title, authors
            case firstPublishYear = "first_publish_year"
            case coverID = "cover_id"
        }
    }

    private struct OLSubjectAuthor: Decodable {
        let name: String?
    }

    static func bookCandidates(from data: Data) throws -> [MediaCandidate] {
        let response = try JSONDecoder().decode(OLSubjectResponse.self, from: data)
        return (response.works ?? []).map { work in
            MediaCandidate(
                title: work.title,
                primaryCreator: work.authors?.first?.name,
                year: work.firstPublishYear,
                coverURL: work.coverID.flatMap {
                    URL(string: "https://covers.openlibrary.org/b/id/\($0)-M.jpg")
                },
                overview: nil,
                // Strip the "/works/" prefix so external_id matches what
                // OpenLibraryService.workKey(from:) produces.
                externalID: work.key.replacingOccurrences(of: "/works/", with: ""),
                externalSource: .openlibrary,
                kind: .book
            )
        }
    }

    // MARK: - MusicBrainz wire format

    /// `MusicBrainzService`'s own response wrapper is private, so this
    /// declares its own. `MBReleaseGroup` and `candidate(from:)` are
    /// internal and reused rather than duplicated.
    private struct MBBrowseResponse: Decodable {
        let releaseGroups: [MBReleaseGroup]

        enum CodingKeys: String, CodingKey {
            case releaseGroups = "release-groups"
        }
    }

    private struct MBGroupWithArtist: Decodable {
        let artistCredit: [MBCreditWithArtist]?

        enum CodingKeys: String, CodingKey {
            case artistCredit = "artist-credit"
        }
    }

    private struct MBCreditWithArtist: Decodable {
        let artist: MBArtistRef?
    }

    private struct MBArtistRef: Decodable {
        let id: String
    }
}
```

**Verified signatures** (do not re-derive): `ExternalAPI.year(from: String?) -> Int?` exists as used. `MusicBrainzService.candidate(from: MBReleaseGroup)` and the `MBReleaseGroup` / `MBArtistCredit` types are internal and reused above. `OpenLibraryService.candidate(from:)` takes an `OLDoc` from the _search_ payload and cannot decode the subjects endpoint, which is why `bookCandidates(from:)` above declares its own wire types rather than reaching for it.

- [ ] **Step 4: Run and watch pass**

```bash
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData build-for-testing 2>&1 | tail -3
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData -only-testing:VennTests test-without-building 2>&1 \
  | grep -E "✘|Test run with"
```

Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add ios/Venn/Features/Explorer/Recommendations/CatalogSimilarService.swift \
  ios/VennTests/Features/Explorer/CatalogSimilarServiceTests.swift
git commit -m "feat(ios): fetch similar titles and trending from the catalogs

TMDB's trending endpoint returns people alongside films and shows; they
are dropped rather than rendered as coverless cards. Books and music have
no similar-title endpoint and fall back to same-subject and same-artist."
```

---

### Task 9: iOS — view-model, views, and Explorer

**Files:**

- Create: `ios/Venn/Features/Explorer/Recommendations/RecommendationsViewModel.swift`
- Create: `ios/Venn/Features/Explorer/Recommendations/RecommendationShelfView.swift`
- Create: `ios/Venn/Features/Explorer/Recommendations/RecommendationsView.swift`
- Test: `ios/VennTests/Features/Explorer/RecommendationsViewModelTests.swift`
- Modify: `ios/Venn/Features/Explorer/ExplorerView.swift`

**Interfaces:**

- Consumes: everything from Tasks 6–8
- Produces: `RecommendationsViewModel` with `state: LoadState<[RecommendationShelf]>` and `func load() async`

- [ ] **Step 1: Write the failing tests**

Create `ios/VennTests/Features/Explorer/RecommendationsViewModelTests.swift`:

```swift
import Foundation
import Testing
@testable import Venn

@MainActor
struct RecommendationsViewModelTests {
    @Test
    func aFailedCatalogCallCostsOneShelfNotThePage() async {
        // Providers are independent: one being down must not blank the tab.
        let feed = RecommendationService.FakeFeed.withSeeds
        let catalog = FakeCatalogSimilarService()
        catalog.similarError = AppError.network
        catalog.trendingResult = (1...4).map { FakeCatalogSimilarService.candidate("\($0)") }

        let viewModel = RecommendationsViewModel(
            service: FakeRecommendationService(feed: feed),
            catalog: catalog
        )
        await viewModel.load()

        guard case let .loaded(shelves) = viewModel.state else {
            Issue.record("expected a loaded state")
            return
        }
        #expect(shelves.map(\.source) == [.trending])
    }

    @Test
    func onlyTheRPCFailingIsAnErrorState() async {
        let service = FakeRecommendationService(feed: .empty)
        service.error = AppError.network
        let viewModel = RecommendationsViewModel(
            service: service,
            catalog: FakeCatalogSimilarService()
        )

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func aBrandNewUserGetsNoShelvesRatherThanAnError() async {
        // Empty everything is the normal cold-start payload.
        let viewModel = RecommendationsViewModel(
            service: FakeRecommendationService(feed: .empty),
            catalog: FakeCatalogSimilarService()
        )

        await viewModel.load()

        #expect(viewModel.state == .loaded([]))
    }
}

final class FakeRecommendationService: RecommendationServicing, @unchecked Sendable {
    let seeded: RecommendationFeed
    var error: AppError?

    init(feed: RecommendationFeed) {
        seeded = feed
    }

    func feed() async throws -> RecommendationFeed {
        if let error { throw error }
        return seeded
    }
}

final class FakeCatalogSimilarService: CatalogSimilarServicing, @unchecked Sendable {
    var similarResult: [MediaCandidate] = []
    var trendingResult: [MediaCandidate] = []
    var similarError: AppError?
    var trendingError: AppError?

    static func candidate(_ externalID: String) -> MediaCandidate {
        MediaCandidate(
            title: "Title \(externalID)",
            primaryCreator: nil,
            year: nil,
            coverURL: nil,
            overview: nil,
            externalID: externalID,
            externalSource: .tmdb,
            kind: .movie
        )
    }

    func similar(to _: RecommendationSeed) async throws -> [MediaCandidate] {
        if let similarError { throw similarError }
        return similarResult
    }

    func trending() async throws -> [MediaCandidate] {
        if let trendingError { throw trendingError }
        return trendingResult
    }
}

extension RecommendationService {
    /// Fixture used by the view-model tests.
    enum FakeFeed {
        static let withSeeds = RecommendationFeed(
            sections: [],
            seeds: [RecommendationSeed(
                mediaID: UUID(),
                title: "Past Lives",
                kind: .movie,
                externalSource: .tmdb,
                externalID: "666277",
                rating: 5
            )],
            excluded: []
        )
    }
}
```

`RecommendationSeed` needs a memberwise initialiser for this fixture. It is `Decodable` with `let` properties, so Swift synthesises one automatically — no extra code needed.

- [ ] **Step 2: Run and watch fail**

```bash
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData build-for-testing 2>&1 | grep -E "error:" | sort -u
```

Expected: `cannot find 'RecommendationsViewModel' in scope`.

- [ ] **Step 3: Write the view-model**

Create `ios/Venn/Features/Explorer/Recommendations/RecommendationsViewModel.swift`:

```swift
import Foundation
import Observation

/// Drives the recommendation shelves above Explorer's browse grid.
///
/// Uses the shared `LoadState` machine rather than a per-feature enum
/// (docs/ARCHITECTURE.md, "The standard load pattern").
@MainActor
@Observable
final class RecommendationsViewModel {
    typealias State = LoadState<[RecommendationShelf]>

    private(set) var state: State = .loading

    private let service: any RecommendationServicing
    private let catalog: any CatalogSimilarServicing

    init(service: any RecommendationServicing, catalog: any CatalogSimilarServicing) {
        self.service = service
        self.catalog = catalog
    }

    func load() async {
        state = .loading
        do {
            let feed = try await service.feed()
            state = await .loaded(shelves(for: feed))
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }

    /// Catalog failures cost one shelf each, never the page: the providers
    /// are independent of each other and of the RPC, so one being down
    /// should thin the screen rather than blank it. Only the RPC itself
    /// failing is an error state, and even then Explorer's browse grid
    /// still renders below.
    private func shelves(for feed: RecommendationFeed) async -> [RecommendationShelf] {
        var candidateShelves: [CandidateShelf] = []

        for seed in feed.seeds {
            let candidates = (try? await catalog.similar(to: seed)) ?? []
            candidateShelves.append(CandidateShelf(
                source: .similar,
                seedTitle: seed.title,
                candidates: candidates
            ))
        }

        let trending = (try? await catalog.trending()) ?? []
        candidateShelves.append(CandidateShelf(
            source: .trending,
            seedTitle: nil,
            candidates: trending
        ))

        return RecommendationAssembler.assembleShelves(
            feed: feed,
            candidateShelves: candidateShelves
        )
    }
}
```

- [ ] **Step 4: Write the shelf view**

Create `ios/Venn/Features/Explorer/Recommendations/RecommendationShelfView.swift`:

```swift
import SwiftUI

/// One horizontal shelf: a heading and a row of covers.
///
/// A catalog result is not in `public.media` yet, so it has no detail
/// screen to open — tapping it opens the composer instead, which is also
/// the action someone wants after seeing something they like.
struct RecommendationShelfView: View {
    let shelf: RecommendationShelf
    let onSelectCandidate: (MediaCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(shelf.title)
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Color.textPrimary)
                .padding(.horizontal, Theme.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ForEach(shelf.items) { item in
                        card(for: item)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func card(for item: ShelfItem) -> some View {
        switch item {
        case let .media(media):
            NavigationLink(value: media) {
                cover(title: media.title, kind: media.kind, coverURL: media.coverURL)
            }
            .buttonStyle(.plain)
        case let .candidate(candidate):
            Button {
                onSelectCandidate(candidate)
            } label: {
                cover(title: candidate.title, kind: candidate.kind, coverURL: candidate.coverURL)
            }
            .buttonStyle(.plain)
        }
    }

    private func cover(title: String, kind: MediaKind, coverURL: URL?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            MediaCoverTile(
                title: title,
                kind: kind,
                coverURL: coverURL,
                height: 165,
                cornerRadius: Theme.Radius.md
            )
            .frame(width: 110)

            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(2)
                .frame(width: 110, alignment: .leading)
        }
    }
}
```

- [ ] **Step 5: Write the container view**

Create `ios/Venn/Features/Explorer/Recommendations/RecommendationsView.swift`:

```swift
import SwiftUI

/// The recommendation shelves, above Explorer's browse grid.
///
/// Renders nothing when there are no shelves rather than an empty state:
/// the browse grid below is already a reasonable thing to look at, and a
/// "no recommendations yet" message would be noise on top of it.
struct RecommendationsView: View {
    let viewModel: RecommendationsViewModel
    let onSelectCandidate: (MediaCandidate) -> Void

    var body: some View {
        switch viewModel.state {
        case .loading:
            DeferredLoadingView(caption: "Finding things for you…")
        case let .loaded(shelves):
            if !shelves.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ForEach(shelves) { shelf in
                        RecommendationShelfView(shelf: shelf, onSelectCandidate: onSelectCandidate)
                    }
                }
            }
        case let .error(reason):
            // Deliberately quiet: the browse grid below still works, so a
            // full error screen would overstate the damage.
            ErrorStateView(reason: reason, unknownTitle: "Couldn't load recommendations") {
                Task { await viewModel.load() }
            }
        }
    }
}
```

- [ ] **Step 6: Wire into ExplorerView**

In `ios/Venn/Features/Explorer/ExplorerView.swift`:

Add the state property beside the others:

```swift
    @State private var recommendations: RecommendationsViewModel?
```

Inside the `VStack` in `body`, replace the `allBrowsePrompt` branch so recommendations sit under the search field. The existing branch is:

```swift
                        if query.isEmpty {
                            if selectedCategory.browseKind != nil {
                                browseStack
                            } else if selectedCategory == .people {
                                peopleBrowsePrompt
                            } else {
                                allBrowsePrompt
                            }
```

Change the final `else` to:

```swift
                            } else {
                                recommendationsStack
                                allBrowsePrompt
                            }
```

Add the computed property beside the other stacks:

```swift
    /// Only in the "All" category and only with an empty query: shelves are
    /// for browsing, and leaving them above live search results would push
    /// what the user just typed off the screen.
    @ViewBuilder private var recommendationsStack: some View {
        if let recommendations {
            RecommendationsView(viewModel: recommendations) { candidate in
                composerViewModel?.pick(candidate)
            }
        }
    }
```

And in `ensureLoaded()`, after the existing `composerViewModel` setup:

```swift
        if recommendations == nil {
            let viewModel = RecommendationsViewModel(
                service: RecommendationService(client: clientProvider.client),
                catalog: CatalogSimilarService(tmdbAPIKey: config.tmdbAPIKey)
            )
            recommendations = viewModel
            await viewModel.load()
        }
```

`ExplorerView` already registers `.navigationDestination(for: Media.self)`, so the media cards route correctly with no further change.

- [ ] **Step 7: Verify**

```bash
cd /Users/charlessalomon/GitProjects/venn
make lint && make format-check
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData build-for-testing 2>&1 | tail -3
xcodebuild -project ios/Venn.xcodeproj -scheme Venn \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  -derivedDataPath build/DerivedData -only-testing:VennTests test-without-building 2>&1 \
  | grep -E "✘|Test run with"
```

Expected: 0 lint violations, formatting clean, build succeeds, all tests pass.

- [ ] **Step 8: Commit**

```bash
git add ios/Venn/Features/Explorer/Recommendations/ \
  ios/VennTests/Features/Explorer/RecommendationsViewModelTests.swift \
  ios/Venn/Features/Explorer/ExplorerView.swift
git commit -m "feat(ios): show recommendation shelves in Explorer

Shelves sit under the search field in the All category with an empty
query. A catalog provider failing costs one shelf rather than the page;
only the RPC itself failing is an error state, and the browse grid below
still renders either way."
```

---

### Task 10: Close the loop — docs and end-to-end coverage

**Files:**

- Modify: `docs/TECH_DEBT.md`
- Modify: `web/e2e/authenticated/signedIn.spec.ts`

- [ ] **Step 1: Add the end-to-end check**

Append to the `describe("signed in", …)` block in `web/e2e/authenticated/signedIn.spec.ts`:

```ts
test("explorer renders without breaking when recommendations are thin", async ({ page }) => {
  // The E2E user has almost no history, so the interesting assertion is
  // not that shelves appear — it is that a nearly-empty recommendation
  // payload leaves Explorer working rather than blanking it.
  await page.goto("/explorer");

  await expect(page.getByPlaceholder("Search movies, TV, music, books, people")).toBeVisible();
  await expect(page.getByText("Couldn't load")).toHaveCount(0);
});
```

- [ ] **Step 2: Run the E2E suite**

```bash
export PATH="$HOME/.nvm/versions/node/v24.18.1/bin:$PATH"
cd /Users/charlessalomon/GitProjects/venn/web
npm run test:e2e -- --project=authenticated
```

Expected: passes. (Needs `SUPABASE_SERVICE_ROLE_KEY` set locally; without it the spec skips, which is also fine.)

- [ ] **Step 3: Resolve tech-debt row 18**

In `docs/TECH_DEBT.md`, replace row 18's first cell with:

```
| 18 | ~~iOS's Explorer labels its browse panel "Recommended for you" while `ExplorerService.recentMedia` returns the newest catalog rows with no scoring.~~ **RESOLVED 2026-08-06:** real recommendation shelves now sit above the browse grid on both platforms, each labelled for what it actually is. The browse grid remains as the fallback beneath them and is no longer labelled as a recommendation. |
```

- [ ] **Step 4: Add the new debt this creates**

Append two rows to the table, before the `## Figma backlog` heading:

```
| 29 | **`recommendation_feed` has no automated test.** This repo has no SQL test harness, so the one new query that joins across users — and therefore the one most able to leak another account's activity — is covered only by manual verification and an E2E check that the page renders. | Adding a SQL harness (pgTAP, or a seeded test database in CI) is its own project, and was out of proportion to shipping the feature. | Add pgTAP or a seeded CI database, then port the manual checks from the recommendations plan into it — starting with the private-account leak check, which is the one that matters. |
| 30 | **`similar_users` scans posts across all users on every call.** Free at current scale, not free at ten thousand users. | A materialised similarity table needs a refresh schedule and an invalidation story; building it before anyone can measure the problem would be guessing. | Materialise the similarity scores on a schedule. `recommendation_feed`'s signature does not change, so this is an internal swap when query time starts to show. |
```

- [ ] **Step 5: Add the new surfaces to the Figma backlog**

Append to the Figma backlog list in `docs/TECH_DEBT.md`:

```
- Recommendation shelves on both platforms — the horizontal cover rows, their headings, the loading state, and the quiet error treatment that leaves the browse grid usable
```

- [ ] **Step 6: Format and verify everything**

```bash
cd /Users/charlessalomon/GitProjects/venn
npx prettier@3.9.6 --write docs/TECH_DEBT.md
make verify
export PATH="$HOME/.nvm/versions/node/v24.18.1/bin:$PATH"
cd web && npm run test && npx tsc --noEmit && npm run lint
```

Expected: everything passes.

- [ ] **Step 7: Commit and open the PR**

```bash
cd /Users/charlessalomon/GitProjects/venn
git add docs/TECH_DEBT.md web/e2e/authenticated/signedIn.spec.ts
git commit -m "docs: close the Recommended-for-you debt, log what recommendations add

Row 18 was a label making a claim the code did not support. It does now.
Two new rows replace it: the recommendation RPC has no automated test
because this repo has no SQL harness, and similar_users scans across
users on every call."
git push -u origin feat/recommendations
gh pr create --base main --title "feat: recommendations in the Explorer tab" --body "…"
```

---

## Self-Review

**Spec coverage.** Every section of the spec maps to a task: the ladder and both venn-data tiers to Task 2; exclusions to Tasks 2, 3 and 7; the RPC contract to Tasks 2 and 6; client assembly and the drift containment to Tasks 3 and 7; the file structure to Tasks 3–9; states to Task 9; testing to every task plus Task 10; the "explicitly out of scope" list is respected — no impression tracking, no genre tier, no push.

**One gap found and fixed:** the spec's exclusion-key example omitted `kind`, while web's `candidateId()` has always included it. Since the key is a cross-platform contract, the mismatch would have silently broken the "already seen" filter for TV. The spec is corrected and Task 1 now fixes iOS's `MediaCandidate.id` before anything depends on it.

**Type consistency.** `ShelfSource` is `taste_twins | followed | similar | trending` in SQL, TypeScript and Swift. `assembleShelves(feed:candidateShelves:)` takes the same two arguments on both platforms. `MIN_SHELF_ITEMS`/`minShelfItems` = 3, `MAX_SHELVES`/`maxShelves` = 4, `MAX_SHELF_ITEMS`/`maxShelfItems` = 12 on both. The exclusion key is `"<source>:<kind>:<externalId>"` in all four places it is built.

**A second gap found and fixed:** Task 8 originally called `OpenLibraryService.candidates(from:)` and `MusicBrainzService.candidates(from:)`, neither of which exists — both services expose per-item mappers over their _search_ wire types, and `MusicBrainzService`'s response wrapper is private. The OpenLibrary subjects endpoint also returns a different shape from search (`works`/`cover_id` rather than `docs`/`cover_i`), so the search mapper could not have decoded it. Task 8 now declares its own wire types for both, reuses the internal `MBReleaseGroup` and `candidate(from:)`, and fetches the MusicBrainz artist in two steps because browsing by artist needs an MBID the seed does not carry. `ExternalAPI.year(from:)` was verified to exist as used.
