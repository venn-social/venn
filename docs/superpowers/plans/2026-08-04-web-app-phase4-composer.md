# Web App Phase 4: The Composer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a web user search a media catalog, pick something, and log or save it — closing the product's core loop on web, which currently has zero posts.

**Architecture:** All three catalog APIs are called from one Next.js Route Handler so the TMDB key never reaches the browser and MusicBrainz gets a proper `User-Agent`. The composer page is a client component owning a small state machine; the write goes through the browser's Supabase client under RLS. A Postgres trigger rate-limits post inserts for both platforms at once.

**Tech Stack:** Next.js 16 (App Router, Route Handlers), `@supabase/supabase-js`, Tailwind v4, Vitest, React Testing Library, Playwright, Postgres/plpgsql.

## Global Constraints

- Node 24 (`.nvmrc`) — run `nvm use` in `web/` before any command.
- Design tokens only: the `--color-*` vars in `app/globals.css` and Tailwind's numeric spacing scale. **Never** add a named `--spacing-*` key (it hijacks `max-w-*`/`h-*` of the same name — see the comment in `globals.css`).
- Copy mirrors the iOS source referenced in each task, per CLAUDE.md rule 17.
- `TMDB_API_KEY` is **server-only** — never prefix it `NEXT_PUBLIC_`, never import it into a client component. It is already set in `web/.env.local`.
- No `next/image` — plain `<img loading="lazy">`, same as the rest of web.
- Rating mapping is fixed: Love → `rated` 5.0, Like → `rated` 3.0, Dislike → `rated` 1.0, skip → `logged` + null rating, watchlist → `saved` + null rating + null caption.
- Format markdown with the lockfile-pinned prettier (`npx prettier@3.9.6`), never the local binary — versions drift and CI checks the whole repo.
- All work stays on branch `feat/web-composer`.

## File Structure

| File                                        | Responsibility                                   |
| ------------------------------------------- | ------------------------------------------------ |
| `supabase/migrations/*_post_rate_limit.sql` | BEFORE INSERT trigger limiting posts to 30/min   |
| `web/lib/catalog/types.ts`                  | `MediaCandidate`, `ExternalSource`, year parsing |
| `web/lib/catalog/tmdb.ts`                   | Movies + shows normalizer and fetch              |
| `web/lib/catalog/openLibrary.ts`            | Books normalizer and fetch                       |
| `web/lib/catalog/musicBrainz.ts`            | Albums normalizer and fetch                      |
| `web/app/api/catalog/search/route.ts`       | Auth + rate limit + provider fan-out             |
| `web/lib/compose.ts`                        | Media upsert, post insert, rating mapping        |
| `web/components/Composer.tsx`               | The state machine                                |
| `web/components/CandidateList.tsx`          | Search results                                   |
| `web/components/RatingChips.tsx`            | Love / Like / Dislike                            |
| `web/app/(app)/composer/page.tsx`           | Auth-gated route                                 |

---

### Task 1: Post rate-limit migration

**Files:**

- Create: `supabase/migrations/20260804180000_post_rate_limit.sql`

**Interfaces:**

- Consumes: the existing `public.rl_check(text, int, interval)` from `20260611230000_overlap_rpc.sql`.
- Produces: no client-visible API; inserts exceeding the limit raise SQLSTATE `P0429`.

A trigger rather than an RPC so it covers every insert path — iOS inserts directly into `posts` today and gets this protection with no Swift change and no App Store release.

- [ ] **Step 1: Write the migration**

Create `supabase/migrations/20260804180000_post_rate_limit.sql`:

```sql
-- =============================================================================
-- 20260804180000_post_rate_limit.sql — cap how fast one author can post.
-- =============================================================================
-- `posts_insert_own` (20260425120000_init.sql) proves *ownership* — that the
-- author_id is the caller — but says nothing about *frequency*. Nothing stops
-- a script inserting thousands of rows as itself.
--
-- This is a trigger rather than a create_post RPC on purpose: a trigger covers
-- every insert path, so the iOS app (which inserts into posts directly) is
-- protected immediately, with no Swift change and no App Store release. An RPC
-- would only protect callers that remember to use it.
--
-- 30/minute per author is far above any human logging session — even bulk
-- entry after a binge — while stopping a runaway loop.
--
-- Raises P0429, which AppError.from(_:) already maps to AppError.rateLimited
-- on iOS, and which lib/compose.ts maps to user-facing copy on web.
--
-- Idempotent: safe to replay.
-- =============================================================================

create or replace function public.enforce_post_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.rl_check('create_post:' || new.author_id::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_rate_limit on public.posts;
create trigger posts_rate_limit
  before insert on public.posts
  for each row
  execute function public.enforce_post_rate_limit();
```

- [ ] **Step 2: Verify the SQL parses without applying it**

The migration is **not** pushed by this plan — applying it is the founder's call, same as the reserved-usernames migration. Confirm it is well-formed by reading it back:

Run: `cat supabase/migrations/20260804180000_post_rate_limit.sql`
Expected: the file above, with `create trigger posts_rate_limit` present.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/20260804180000_post_rate_limit.sql
git commit -m "feat(db): rate-limit post inserts to 30/min per author"
```

---

### Task 2: `lib/catalog/types.ts`

**Files:**

- Create: `web/lib/catalog/types.ts`
- Test: `web/lib/catalog/__tests__/types.test.ts`

**Interfaces:**

- Consumes: `MediaKind` from `@/lib/media`.
- Produces: `type ExternalSource = "tmdb" | "openlibrary" | "musicbrainz"`; `interface MediaCandidate { id, title, primaryCreator, year, coverUrl, overview, externalId, externalSource, kind }`; `yearFrom(dateString: string | null | undefined): number | null`.

Mirrors `ios/Venn/Models/MediaCandidate.swift` and `ExternalAPI.year(from:)`.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/catalog/__tests__/types.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { candidateId, yearFrom } from "@/lib/catalog/types";

describe("yearFrom", () => {
  it("parses a year from a full ISO date", () => {
    expect(yearFrom("2023-06-02")).toBe(2023);
  });

  it("parses a year from a year-month string", () => {
    expect(yearFrom("2016-05")).toBe(2016);
  });

  it("parses a bare year", () => {
    expect(yearFrom("1999")).toBe(1999);
  });

  it("returns null for a string too short to hold a year", () => {
    expect(yearFrom("99")).toBeNull();
  });

  it("returns null for null, undefined, and empty", () => {
    expect(yearFrom(null)).toBeNull();
    expect(yearFrom(undefined)).toBeNull();
    expect(yearFrom("")).toBeNull();
  });

  it("returns null when the first four characters are not a number", () => {
    expect(yearFrom("n/a-01-01")).toBeNull();
  });
});

describe("candidateId", () => {
  it("namespaces the external id by its source", () => {
    // Two providers can hand back the same raw id; the pair is what's unique.
    expect(candidateId("tmdb", "123")).toBe("tmdb:123");
    expect(candidateId("openlibrary", "123")).toBe("openlibrary:123");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- catalog/__tests__/types`
Expected: FAIL — `Cannot find module '@/lib/catalog/types'`.

- [ ] **Step 3: Write the implementation**

Create `web/lib/catalog/types.ts`:

```ts
import type { MediaKind } from "@/lib/media";

/** Mirrors ios/Venn/Models/Media.swift's ExternalSource. */
export type ExternalSource = "tmdb" | "openlibrary" | "musicbrainz";

/**
 * A search result from an external catalog, before it is persisted to
 * public.media. Mirrors ios/Venn/Models/MediaCandidate.swift.
 */
export interface MediaCandidate {
  /** "<source>:<externalId>" — stable and unique across providers. */
  id: string;
  title: string;
  primaryCreator: string | null;
  year: number | null;
  coverUrl: string | null;
  /** Plot/description. Null for music — MusicBrainz doesn't surface one. */
  overview: string | null;
  externalId: string;
  externalSource: ExternalSource;
  kind: MediaKind;
}

export function candidateId(source: ExternalSource, externalId: string): string {
  return `${source}:${externalId}`;
}

/**
 * Pulls a year out of the assorted date shapes these APIs return
 * ("2023-06-02", "2016-05", "1999"). Ports ExternalAPI.year(from:).
 */
export function yearFrom(dateString: string | null | undefined): number | null {
  if (!dateString || dateString.length < 4) return null;
  const year = Number.parseInt(dateString.slice(0, 4), 10);
  return Number.isNaN(year) ? null : year;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- catalog/__tests__/types`
Expected: PASS — 8 tests green.

- [ ] **Step 5: Commit**

```bash
git add web/lib/catalog/types.ts web/lib/catalog/__tests__/types.test.ts
git commit -m "feat(web): add catalog candidate types and year parsing"
```

---

### Task 3: The three provider modules

**Files:**

- Create: `web/lib/catalog/tmdb.ts`, `web/lib/catalog/openLibrary.ts`, `web/lib/catalog/musicBrainz.ts`
- Test: `web/lib/catalog/__tests__/providers.test.ts`

**Interfaces:**

- Consumes: `MediaCandidate`, `ExternalSource`, `candidateId`, `yearFrom` from `@/lib/catalog/types`.
- Produces: `toMovieCandidates(json: unknown): MediaCandidate[]`; `toShowCandidates(json: unknown): MediaCandidate[]`; `searchTMDB(kind, query, apiKey): Promise<MediaCandidate[]>`; `toBookCandidates(json: unknown): MediaCandidate[]`; `searchOpenLibrary(query): Promise<MediaCandidate[]>`; `toAlbumCandidates(json: unknown): MediaCandidate[]`; `searchMusicBrainz(query): Promise<MediaCandidate[]>`.

One task because the three normalizers share one test file and are only meaningful together — a reviewer would accept or reject the catalog layer as a unit.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/catalog/__tests__/providers.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { toAlbumCandidates } from "@/lib/catalog/musicBrainz";
import { toBookCandidates } from "@/lib/catalog/openLibrary";
import { toMovieCandidates, toShowCandidates } from "@/lib/catalog/tmdb";

describe("toMovieCandidates", () => {
  it("maps a complete movie", () => {
    const [movie] = toMovieCandidates({
      results: [
        {
          id: 12345,
          title: "Past Lives",
          release_date: "2023-06-02",
          poster_path: "/abc.jpg",
          overview: "Two friends reunite."
        }
      ]
    });

    expect(movie.title).toBe("Past Lives");
    expect(movie.year).toBe(2023);
    expect(movie.kind).toBe("movie");
    expect(movie.externalSource).toBe("tmdb");
    expect(movie.externalId).toBe("12345");
    expect(movie.coverUrl).toBe("https://image.tmdb.org/t/p/w500/abc.jpg");
    expect(movie.overview).toBe("Two friends reunite.");
  });

  it("handles a movie with no poster, date, or overview", () => {
    const [movie] = toMovieCandidates({
      results: [{ id: 1, title: "Untitled", release_date: "", poster_path: null }]
    });

    expect(movie.coverUrl).toBeNull();
    expect(movie.year).toBeNull();
    expect(movie.overview).toBeNull();
  });

  it("returns an empty array when results is missing or not an array", () => {
    expect(toMovieCandidates({})).toEqual([]);
    expect(toMovieCandidates({ results: null })).toEqual([]);
    expect(toMovieCandidates(null)).toEqual([]);
  });

  it("skips entries missing an id or title rather than emitting junk rows", () => {
    const candidates = toMovieCandidates({
      results: [{ id: 1 }, { title: "No id" }, { id: 2, title: "Fine" }]
    });
    expect(candidates.map((candidate) => candidate.title)).toEqual(["Fine"]);
  });
});

describe("toShowCandidates", () => {
  it("reads name and first_air_date rather than title and release_date", () => {
    // TMDB uses different field names for TV — mixing them up yields
    // untitled, undated results.
    const [show] = toShowCandidates({
      results: [{ id: 99, name: "Severance", first_air_date: "2022-02-18", poster_path: "/s.jpg" }]
    });

    expect(show.title).toBe("Severance");
    expect(show.year).toBe(2022);
    expect(show.kind).toBe("show");
  });
});

describe("toBookCandidates", () => {
  it("maps a complete book", () => {
    const [book] = toBookCandidates({
      docs: [
        {
          key: "/works/OL123W",
          title: "Piranesi",
          author_name: ["Susanna Clarke", "Someone Else"],
          first_publish_year: 2020,
          cover_i: 987,
          first_sentence: { value: "The Halls are endless." }
        }
      ]
    });

    expect(book.title).toBe("Piranesi");
    // Only the first author, matching OpenLibraryService.
    expect(book.primaryCreator).toBe("Susanna Clarke");
    expect(book.year).toBe(2020);
    expect(book.externalId).toBe("OL123W");
    expect(book.coverUrl).toBe("https://covers.openlibrary.org/b/id/987-M.jpg");
    expect(book.overview).toBe("The Halls are endless.");
    expect(book.kind).toBe("book");
  });

  it("strips only the /works/ prefix and passes a bare key through", () => {
    const [bare] = toBookCandidates({ docs: [{ key: "OL9W", title: "Bare" }] });
    expect(bare.externalId).toBe("OL9W");
  });

  it("handles a book with no cover, author, year, or sentence", () => {
    const [sparse] = toBookCandidates({ docs: [{ key: "/works/OL1W", title: "Sparse" }] });

    expect(sparse.coverUrl).toBeNull();
    expect(sparse.primaryCreator).toBeNull();
    expect(sparse.year).toBeNull();
    expect(sparse.overview).toBeNull();
  });

  it("accepts first_sentence given as a plain string", () => {
    // OpenLibrary returns either {value} or a bare string depending on the record.
    const [book] = toBookCandidates({
      docs: [{ key: "/works/OL2W", title: "Stringy", first_sentence: "Just a string." }]
    });
    expect(book.overview).toBe("Just a string.");
  });
});

describe("toAlbumCandidates", () => {
  it("maps a complete release group", () => {
    const [album] = toAlbumCandidates({
      "release-groups": [
        {
          id: "mbid-1",
          title: "A Moon Shaped Pool",
          "artist-credit": [{ name: "Radiohead" }],
          "first-release-date": "2016-05-08"
        }
      ]
    });

    expect(album.title).toBe("A Moon Shaped Pool");
    expect(album.primaryCreator).toBe("Radiohead");
    expect(album.year).toBe(2016);
    expect(album.kind).toBe("album");
    expect(album.coverUrl).toBe("https://coverartarchive.org/release-group/mbid-1/front-500");
    // MusicBrainz surfaces no description.
    expect(album.overview).toBeNull();
  });

  it("handles a release group with no artist credit or date", () => {
    const [album] = toAlbumCandidates({
      "release-groups": [{ id: "mbid-2", title: "Untitled" }]
    });

    expect(album.primaryCreator).toBeNull();
    expect(album.year).toBeNull();
  });

  it("returns an empty array when release-groups is absent", () => {
    expect(toAlbumCandidates({})).toEqual([]);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- providers`
Expected: FAIL — cannot find `@/lib/catalog/tmdb`.

- [ ] **Step 3: Write `tmdb.ts`**

Create `web/lib/catalog/tmdb.ts`:

```ts
import { candidateId, yearFrom, type MediaCandidate } from "@/lib/catalog/types";

const API_BASE = "https://api.themoviedb.org/3";
/** Same pixel budget as TMDBService.posterBase. */
const POSTER_BASE = "https://image.tmdb.org/t/p/w500";

interface TMDBResult {
  id?: number;
  title?: string;
  name?: string;
  release_date?: string | null;
  first_air_date?: string | null;
  poster_path?: string | null;
  overview?: string | null;
}

function resultsOf(json: unknown): TMDBResult[] {
  const results = (json as { results?: unknown } | null)?.results;
  return Array.isArray(results) ? (results as TMDBResult[]) : [];
}

function toCandidate(result: TMDBResult, kind: "movie" | "show"): MediaCandidate | null {
  // TMDB names these fields differently for film and television.
  const title = kind === "movie" ? result.title : result.name;
  const date = kind === "movie" ? result.release_date : result.first_air_date;
  if (result.id === undefined || !title) return null;

  const externalId = String(result.id);
  return {
    id: candidateId("tmdb", externalId),
    title,
    primaryCreator: null,
    year: yearFrom(date),
    coverUrl: result.poster_path ? `${POSTER_BASE}${result.poster_path}` : null,
    overview: result.overview || null,
    externalId,
    externalSource: "tmdb",
    kind
  };
}

export function toMovieCandidates(json: unknown): MediaCandidate[] {
  return resultsOf(json)
    .map((result) => toCandidate(result, "movie"))
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

export function toShowCandidates(json: unknown): MediaCandidate[] {
  return resultsOf(json)
    .map((result) => toCandidate(result, "show"))
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

/** Server-only: `apiKey` must never be passed from a client component. */
export async function searchTMDB(
  kind: "movie" | "show",
  query: string,
  apiKey: string
): Promise<MediaCandidate[]> {
  const path = kind === "movie" ? "movie" : "tv";
  const url = `${API_BASE}/search/${path}?api_key=${encodeURIComponent(apiKey)}&query=${encodeURIComponent(query)}&page=1`;

  const response = await fetch(url);
  if (!response.ok) throw new Error(`TMDB search failed (${response.status})`);

  const json: unknown = await response.json();
  return kind === "movie" ? toMovieCandidates(json) : toShowCandidates(json);
}
```

- [ ] **Step 4: Write `openLibrary.ts`**

Create `web/lib/catalog/openLibrary.ts`:

```ts
// No yearFrom here: OpenLibrary returns first_publish_year already numeric,
// unlike TMDB's and MusicBrainz's date strings.
import { candidateId, type MediaCandidate } from "@/lib/catalog/types";

const API_BASE = "https://openlibrary.org";
const COVERS_BASE = "https://covers.openlibrary.org/b/id";

interface OLDoc {
  key?: string;
  title?: string;
  author_name?: string[];
  first_publish_year?: number;
  cover_i?: number;
  // Some records return {value}, others a bare string.
  first_sentence?: { value?: string } | string;
}

function firstSentence(doc: OLDoc): string | null {
  if (typeof doc.first_sentence === "string") return doc.first_sentence || null;
  return doc.first_sentence?.value || null;
}

export function toBookCandidates(json: unknown): MediaCandidate[] {
  const docs = (json as { docs?: unknown } | null)?.docs;
  if (!Array.isArray(docs)) return [];

  return (docs as OLDoc[])
    .map((doc): MediaCandidate | null => {
      if (!doc.key || !doc.title) return null;
      // "/works/OL123W" → "OL123W"; a bare key passes through untouched.
      const externalId = doc.key.replace(/^\/works\//, "");

      return {
        id: candidateId("openlibrary", externalId),
        title: doc.title,
        primaryCreator: doc.author_name?.[0] ?? null,
        year: doc.first_publish_year ?? null,
        coverUrl: doc.cover_i ? `${COVERS_BASE}/${doc.cover_i}-M.jpg` : null,
        overview: firstSentence(doc),
        externalId,
        externalSource: "openlibrary",
        kind: "book"
      };
    })
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

export async function searchOpenLibrary(query: string): Promise<MediaCandidate[]> {
  const url = `${API_BASE}/search.json?q=${encodeURIComponent(query)}&page=1`;
  const response = await fetch(url);
  if (!response.ok) throw new Error(`OpenLibrary search failed (${response.status})`);
  return toBookCandidates(await response.json());
}
```

- [ ] **Step 5: Write `musicBrainz.ts`**

Create `web/lib/catalog/musicBrainz.ts`:

```ts
import { candidateId, yearFrom, type MediaCandidate } from "@/lib/catalog/types";

const API_BASE = "https://musicbrainz.org/ws/2";
/**
 * MusicBrainz requires a User-Agent identifying the application and will
 * throttle or block generic ones. A browser can't set this header, which is
 * one reason album search runs server-side (see the Phase 4 spec).
 */
const USER_AGENT = "Venn/1.0 (social.venn.app)";
const PAGE_SIZE = 20;

interface MBReleaseGroup {
  id?: string;
  title?: string;
  "artist-credit"?: { name?: string }[];
  "first-release-date"?: string;
}

/**
 * Cover Art Archive front cover, 500px — the same budget as TMDB's w500.
 * Constructed blind: CAA 404s when no art exists and the tile falls back to
 * its placeholder, so a wrong guess costs nothing.
 */
function coverUrl(releaseGroupId: string): string {
  return `https://coverartarchive.org/release-group/${releaseGroupId}/front-500`;
}

export function toAlbumCandidates(json: unknown): MediaCandidate[] {
  const groups = (json as { "release-groups"?: unknown } | null)?.["release-groups"];
  if (!Array.isArray(groups)) return [];

  return (groups as MBReleaseGroup[])
    .map((group): MediaCandidate | null => {
      if (!group.id || !group.title) return null;

      return {
        id: candidateId("musicbrainz", group.id),
        title: group.title,
        primaryCreator: group["artist-credit"]?.[0]?.name ?? null,
        year: yearFrom(group["first-release-date"]),
        coverUrl: coverUrl(group.id),
        overview: null,
        externalId: group.id,
        externalSource: "musicbrainz",
        kind: "album"
      };
    })
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

export async function searchMusicBrainz(query: string): Promise<MediaCandidate[]> {
  const url = `${API_BASE}/release-group?query=${encodeURIComponent(query)}&fmt=json&limit=${PAGE_SIZE}&offset=0`;
  const response = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
  if (!response.ok) throw new Error(`MusicBrainz search failed (${response.status})`);
  return toAlbumCandidates(await response.json());
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd web && npm run test -- providers`
Expected: PASS — 11 tests green.

- [ ] **Step 7: Commit**

```bash
git add web/lib/catalog web/lib/catalog/__tests__
git commit -m "feat(web): add TMDB, OpenLibrary, and MusicBrainz catalog clients"
```

---

### Task 4: The search Route Handler

**Files:**

- Create: `web/app/api/catalog/search/route.ts`

**Interfaces:**

- Consumes: `searchTMDB`, `searchOpenLibrary`, `searchMusicBrainz`; `createClient` from `@/lib/supabase/server`.
- Produces: `GET /api/catalog/search?kind=<movie|show|book|album>&q=<query>` → `200 { candidates }` | `400 { error }` | `401 { error }` | `429 { error }` | `500 { error }`.

- [ ] **Step 1: Write the route handler**

Create `web/app/api/catalog/search/route.ts`:

```ts
import { NextResponse, type NextRequest } from "next/server";
import { searchMusicBrainz } from "@/lib/catalog/musicBrainz";
import { searchOpenLibrary } from "@/lib/catalog/openLibrary";
import { searchTMDB } from "@/lib/catalog/tmdb";
import { createClient } from "@/lib/supabase/server";

const KINDS = ["movie", "show", "book", "album"] as const;
type Kind = (typeof KINDS)[number];

/**
 * Catalog search. Runs server-side for three reasons: TMDB_API_KEY never
 * reaches the browser, MusicBrainz needs a User-Agent a browser can't set,
 * and one endpoint gives one place to rate-limit.
 *
 * Requires a session — an unauthenticated proxy to the TMDB quota is exactly
 * the risk being avoided.
 */
export async function GET(request: NextRequest) {
  const kind = request.nextUrl.searchParams.get("kind");
  const query = request.nextUrl.searchParams.get("q")?.trim();

  if (!kind || !KINDS.includes(kind as Kind)) {
    return NextResponse.json({ error: "Unknown media kind." }, { status: 400 });
  }
  if (!query) {
    return NextResponse.json({ candidates: [] });
  }

  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Sign in to search." }, { status: 401 });
  }

  // Sliding window in Postgres, not in memory: Route Handlers run
  // serverless, so an in-process counter resets on cold start and isn't
  // shared between instances — it would enforce nothing.
  const { data: allowed, error: limitError } = await supabase.rpc("rl_check", {
    _key: `catalog_search:${user.id}`,
    _limit: 60,
    _window: "00:01:00"
  });
  if (!limitError && allowed === false) {
    return NextResponse.json({ error: "Too many searches — give it a moment." }, { status: 429 });
  }

  try {
    const candidates = await searchFor(kind as Kind, query);
    return NextResponse.json({ candidates });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Search failed.";
    return NextResponse.json({ error: message }, { status: 502 });
  }
}

async function searchFor(kind: Kind, query: string) {
  if (kind === "book") return searchOpenLibrary(query);
  if (kind === "album") return searchMusicBrainz(query);

  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey) {
    // Mirrors iOS's AppError.validation for the same missing-key case.
    throw new Error("Movie and show search needs a TMDB API key.");
  }
  return searchTMDB(kind, query, apiKey);
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd web && npm run build`
Expected: succeeds, and the route list includes `/api/catalog/search`.

- [ ] **Step 3: Commit**

```bash
git add web/app/api/catalog/search/route.ts
git commit -m "feat(web): add the server-side catalog search endpoint"
```

---

### Task 5: `sanitizeCaption` + `lib/compose.ts`

**Files:**

- Modify: `web/lib/sanitize.ts`
- Create: `web/lib/compose.ts`
- Test: `web/lib/__tests__/compose.test.ts`, and add cases to `web/lib/__tests__/sanitize.test.ts`

**Interfaces:**

- Consumes: `MediaCandidate`; `PostAction` from `@/lib/feed`; `normalise` from `@/lib/sanitize`.
- Produces: `sanitizeCaption(input: string): SanitizeResult`; `type RatingChoice = "love" | "like" | "dislike"`; `ratingToPost(choice: RatingChoice | null): { action: PostAction; rating: number | null }`; `upsertMedia(client, candidate): Promise<string>`; `createPost(client, opts): Promise<void>`; `isRateLimited(error: unknown): boolean`.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/compose.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { isRateLimited, ratingToPost } from "@/lib/compose";

describe("ratingToPost", () => {
  it("maps Love to a rated post at 5", () => {
    expect(ratingToPost("love")).toEqual({ action: "rated", rating: 5 });
  });

  it("maps Like to a rated post at 3", () => {
    expect(ratingToPost("like")).toEqual({ action: "rated", rating: 3 });
  });

  it("maps Dislike to a rated post at 1", () => {
    expect(ratingToPost("dislike")).toEqual({ action: "rated", rating: 1 });
  });

  it("maps skip to a plain logged post with no rating", () => {
    expect(ratingToPost(null)).toEqual({ action: "logged", rating: null });
  });
});

describe("isRateLimited", () => {
  it("recognises the P0429 the posts trigger raises", () => {
    expect(isRateLimited({ code: "P0429" })).toBe(true);
  });

  it("does not treat other Postgres errors as rate limiting", () => {
    expect(isRateLimited({ code: "23505" })).toBe(false);
    expect(isRateLimited(new Error("network"))).toBe(false);
    expect(isRateLimited(null)).toBe(false);
  });
});
```

Add to `web/lib/__tests__/sanitize.test.ts` (import `sanitizeCaption` alongside the existing imports):

```ts
describe("sanitizeCaption", () => {
  it("accepts a normal caption", () => {
    expect(sanitizeCaption("Devastating.")).toEqual({ valid: true, value: "Devastating." });
  });

  it("rejects an empty or whitespace-only caption", () => {
    expect(sanitizeCaption("")).toEqual({ valid: false, reason: "empty" });
    expect(sanitizeCaption("   ")).toEqual({ valid: false, reason: "empty" });
  });

  it("accepts a caption at exactly 500 characters", () => {
    expect(sanitizeCaption("a".repeat(500))).toEqual({ valid: true, value: "a".repeat(500) });
  });

  it("rejects a caption over 500 characters", () => {
    expect(sanitizeCaption("a".repeat(501))).toEqual({ valid: false, reason: "tooLong" });
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- compose sanitize`
Expected: FAIL — `Cannot find module '@/lib/compose'`, and `sanitizeCaption` is not exported.

- [ ] **Step 3: Add `sanitizeCaption`**

In `web/lib/sanitize.ts`, add after `sanitizeBio`:

```ts
/**
 * Post caption. Required, 1-500 chars after normalise. Mirrors
 * Sanitize.caption and the posts_caption_length constraint.
 */
export function sanitizeCaption(input: string): SanitizeResult {
  const normalised = normalise(input);
  if (normalised.length === 0) return { valid: false, reason: "empty" };
  if (normalised.length > 500) return { valid: false, reason: "tooLong" };
  return { valid: true, value: normalised };
}
```

- [ ] **Step 4: Write `lib/compose.ts`**

Create `web/lib/compose.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import type { MediaCandidate } from "@/lib/catalog/types";
import type { PostAction } from "@/lib/feed";

/** The three-way sentiment from the rating step. Null means "skip". */
export type RatingChoice = "love" | "like" | "dislike";

/** Exactly the mapping ComposerViewModel.submit uses. */
export function ratingToPost(choice: RatingChoice | null): {
  action: PostAction;
  rating: number | null;
} {
  switch (choice) {
    case "love":
      return { action: "rated", rating: 5 };
    case "like":
      return { action: "rated", rating: 3 };
    case "dislike":
      return { action: "rated", rating: 1 };
    default:
      return { action: "logged", rating: null };
  }
}

/** True for the P0429 raised by the posts_rate_limit trigger. */
export function isRateLimited(error: unknown): boolean {
  return (error as { code?: string } | null)?.code === "P0429";
}

/**
 * Returns the id of the existing or newly-inserted media row.
 *
 * Select-then-insert rather than upsert: PostgREST cannot target the partial
 * unique index media_external_unique directly. A concurrent insert of the
 * same (source, id) pair is caught by the constraint, and we re-read rather
 * than fail — the row existing is the outcome we wanted. Ports
 * ComposerService.upsertMedia.
 */
export async function upsertMedia(
  client: SupabaseClient,
  candidate: MediaCandidate
): Promise<string> {
  const existing = await client
    .from("media")
    .select("id")
    .eq("external_source", candidate.externalSource)
    .eq("external_id", candidate.externalId)
    .limit(1);
  if (existing.error) throw existing.error;
  if (existing.data?.[0]) return existing.data[0].id as string;

  const inserted = await client
    .from("media")
    .insert({
      kind: candidate.kind,
      title: candidate.title,
      year: candidate.year,
      primary_creator: candidate.primaryCreator,
      cover_url: candidate.coverUrl,
      external_id: candidate.externalId,
      external_source: candidate.externalSource
    })
    .select("id");

  if (inserted.error) {
    // 23505: someone inserted the same candidate between our select and
    // insert. Re-read theirs instead of surfacing a conflict.
    if (inserted.error.code === "23505") {
      const retry = await client
        .from("media")
        .select("id")
        .eq("external_source", candidate.externalSource)
        .eq("external_id", candidate.externalId)
        .limit(1);
      if (retry.error) throw retry.error;
      if (retry.data?.[0]) return retry.data[0].id as string;
    }
    throw inserted.error;
  }

  const id = inserted.data?.[0]?.id as string | undefined;
  if (!id) throw new Error("Media insert returned no id");
  return id;
}

export async function createPost(
  client: SupabaseClient,
  options: {
    authorId: string;
    mediaId: string;
    action: PostAction;
    rating: number | null;
    caption: string | null;
  }
): Promise<void> {
  const { error } = await client.from("posts").insert({
    author_id: options.authorId,
    media_id: options.mediaId,
    action: options.action,
    rating: options.rating,
    caption: options.caption
  });
  if (error) throw error;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd web && npm run test`
Expected: PASS — all suites green, including the 6 new compose tests and 4 new caption tests.

- [ ] **Step 6: Commit**

```bash
git add web/lib/compose.ts web/lib/sanitize.ts web/lib/__tests__/compose.test.ts web/lib/__tests__/sanitize.test.ts
git commit -m "feat(web): add the compose write path and caption sanitizer"
```

---

### Task 6: `RatingChips` + `CandidateList`

**Files:**

- Create: `web/components/RatingChips.tsx`, `web/components/CandidateList.tsx`
- Test: `web/components/__tests__/RatingChips.test.tsx`

**Interfaces:**

- Consumes: `RatingChoice` from `@/lib/compose`; `MediaCandidate` from `@/lib/catalog/types`.
- Produces: `<RatingChips value={RatingChoice | null} onChange={(next: RatingChoice | null) => void} />`; `<CandidateList candidates={MediaCandidate[]} onPick={(c: MediaCandidate) => void} />`.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/RatingChips.test.tsx`:

```tsx
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { RatingChips } from "@/components/RatingChips";

describe("RatingChips", () => {
  it("offers the same three choices as iOS", () => {
    render(<RatingChips value={null} onChange={() => {}} />);
    expect(screen.getByRole("button", { name: /Love/ })).toBeDefined();
    expect(screen.getByRole("button", { name: /Like/ })).toBeDefined();
    expect(screen.getByRole("button", { name: /Dislike/ })).toBeDefined();
  });

  it("reports the chosen sentiment", () => {
    const onChange = vi.fn();
    render(<RatingChips value={null} onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", { name: /Love/ }));
    expect(onChange).toHaveBeenCalledWith("love");
  });

  it("clears the choice when the selected chip is clicked again", () => {
    // Tapping your current rating should un-set it, so "skip" stays reachable
    // without a separate control.
    const onChange = vi.fn();
    render(<RatingChips value="like" onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", { name: /Like/ }));
    expect(onChange).toHaveBeenCalledWith(null);
  });

  it("marks the selected chip as pressed for assistive tech", () => {
    render(<RatingChips value="dislike" onChange={() => {}} />);
    expect(screen.getByRole("button", { name: /Dislike/ }).getAttribute("aria-pressed")).toBe(
      "true"
    );
    expect(screen.getByRole("button", { name: /Love/ }).getAttribute("aria-pressed")).toBe("false");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- RatingChips`
Expected: FAIL — cannot find `@/components/RatingChips`.

- [ ] **Step 3: Write `RatingChips.tsx`**

Create `web/components/RatingChips.tsx`:

```tsx
"use client";

import type { RatingChoice } from "@/lib/compose";

interface RatingChipsProps {
  value: RatingChoice | null;
  onChange: (next: RatingChoice | null) => void;
}

/** Same three choices and emoji as ComposerSheetView's ratingChip row. */
const CHOICES: { choice: RatingChoice; emoji: string; label: string }[] = [
  { choice: "love", emoji: "❤️", label: "Love" },
  { choice: "like", emoji: "👍", label: "Like" },
  { choice: "dislike", emoji: "👎", label: "Dislike" }
];

export function RatingChips({ value, onChange }: RatingChipsProps) {
  return (
    <div className="flex gap-2">
      {CHOICES.map(({ choice, emoji, label }) => {
        const selected = value === choice;
        return (
          <button
            key={choice}
            type="button"
            aria-pressed={selected}
            // Clicking the current choice clears it, so skipping needs no
            // separate control.
            onClick={() => onChange(selected ? null : choice)}
            className={
              selected
                ? "rounded-pill border border-(--color-accent) bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent)"
                : "rounded-pill border border-(--color-separator) px-4 py-2 font-semibold text-(--color-text-primary)"
            }
          >
            <span aria-hidden="true">{emoji}</span> {label}
          </button>
        );
      })}
    </div>
  );
}
```

- [ ] **Step 4: Write `CandidateList.tsx`**

Create `web/components/CandidateList.tsx`:

```tsx
"use client";

import type { MediaCandidate } from "@/lib/catalog/types";

interface CandidateListProps {
  candidates: MediaCandidate[];
  onPick: (candidate: MediaCandidate) => void;
}

/** Search results — cover thumb, title, and "2023 · Celine Song" metadata. */
export function CandidateList({ candidates, onPick }: CandidateListProps) {
  return (
    <ul className="flex flex-col divide-y divide-(--color-separator)">
      {candidates.map((candidate) => {
        const metadata = [candidate.year?.toString(), candidate.primaryCreator]
          .filter((part): part is string => Boolean(part))
          .join(" · ");

        return (
          <li key={candidate.id}>
            <button
              type="button"
              onClick={() => onPick(candidate)}
              className="flex w-full items-center gap-3 py-2 text-left"
            >
              <span className="flex h-[60px] w-[40px] shrink-0 items-center justify-center overflow-hidden rounded-sm bg-(--color-surface-strong)">
                {candidate.coverUrl && (
                  // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
                  <img
                    src={candidate.coverUrl}
                    alt=""
                    loading="lazy"
                    className="h-full w-full object-cover"
                  />
                )}
              </span>
              <span className="flex flex-col">
                <span className="font-medium text-(--color-text-primary)">{candidate.title}</span>
                {metadata && (
                  <span className="text-sm text-(--color-text-secondary)">{metadata}</span>
                )}
              </span>
            </button>
          </li>
        );
      })}
    </ul>
  );
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd web && npm run test -- RatingChips`
Expected: PASS — 4 tests green.

- [ ] **Step 6: Commit**

```bash
git add web/components/RatingChips.tsx web/components/CandidateList.tsx web/components/__tests__/RatingChips.test.tsx
git commit -m "feat(web): add rating chips and the candidate result list"
```

---

### Task 7: `Composer.tsx` + the route + the nav entry

**Files:**

- Create: `web/components/Composer.tsx`, `web/app/(app)/composer/page.tsx`
- Modify: `web/components/AppNav.tsx`
- Test: `web/components/__tests__/Composer.test.tsx`, `web/e2e/composer.spec.ts`

**Interfaces:**

- Consumes: everything from Tasks 2–6.
- Produces: the `/composer` route and a "Log" nav entry.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/Composer.test.tsx`:

```tsx
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Composer } from "@/components/Composer";

vi.mock("@/lib/supabase/client", () => ({ createClient: () => ({}) }));

const { upsertMedia, createPost } = vi.hoisted(() => ({
  upsertMedia: vi.fn(),
  createPost: vi.fn()
}));

vi.mock("@/lib/compose", async () => {
  const actual = await vi.importActual<typeof import("@/lib/compose")>("@/lib/compose");
  return { ...actual, upsertMedia, createPost };
});

const candidate = {
  id: "tmdb:1",
  title: "Past Lives",
  primaryCreator: "Celine Song",
  year: 2023,
  coverUrl: null,
  overview: null,
  externalId: "1",
  externalSource: "tmdb" as const,
  kind: "movie" as const
};

beforeEach(() => {
  upsertMedia.mockReset().mockResolvedValue("media-1");
  createPost.mockReset().mockResolvedValue(undefined);
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => ({ ok: true, json: async () => ({ candidates: [candidate] }) }))
  );
});

describe("Composer", () => {
  it("shows results for a query and lets one be picked", async () => {
    render(<Composer userId="u1" />);
    fireEvent.change(screen.getByPlaceholderText("Search"), { target: { value: "past lives" } });

    fireEvent.click(await screen.findByRole("button", { name: /Past Lives/ }));

    expect(await screen.findByRole("button", { name: "Log it" })).toBeDefined();
  });

  it("logs a rated post when a sentiment is chosen", async () => {
    render(<Composer userId="u1" />);
    fireEvent.change(screen.getByPlaceholderText("Search"), { target: { value: "past lives" } });
    fireEvent.click(await screen.findByRole("button", { name: /Past Lives/ }));

    fireEvent.click(screen.getByRole("button", { name: /Love/ }));
    fireEvent.click(screen.getByRole("button", { name: "Log it" }));

    await waitFor(() => expect(createPost).toHaveBeenCalled());
    expect(createPost.mock.calls[0][1]).toMatchObject({ action: "rated", rating: 5 });
  });

  it("logs a plain post when no sentiment is chosen", async () => {
    render(<Composer userId="u1" />);
    fireEvent.change(screen.getByPlaceholderText("Search"), { target: { value: "past lives" } });
    fireEvent.click(await screen.findByRole("button", { name: /Past Lives/ }));

    fireEvent.click(screen.getByRole("button", { name: "Log it" }));

    await waitFor(() => expect(createPost).toHaveBeenCalled());
    expect(createPost.mock.calls[0][1]).toMatchObject({ action: "logged", rating: null });
  });

  it("saves to the watchlist without a rating or caption", async () => {
    render(<Composer userId="u1" />);
    fireEvent.change(screen.getByPlaceholderText("Search"), { target: { value: "past lives" } });
    fireEvent.click(await screen.findByRole("button", { name: /Past Lives/ }));

    fireEvent.click(screen.getByRole("button", { name: "Add to watchlist" }));

    await waitFor(() => expect(createPost).toHaveBeenCalled());
    expect(createPost.mock.calls[0][1]).toMatchObject({
      action: "saved",
      rating: null,
      caption: null
    });
  });
});
```

Create `web/e2e/composer.spec.ts`:

```ts
import { expect, test } from "@playwright/test";

test("visiting /composer while signed out redirects to /login", async ({ page }) => {
  await page.goto("/composer");
  await expect(page).toHaveURL(/\/login/);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- Composer`
Expected: FAIL — cannot find `@/components/Composer`.

- [ ] **Step 3: Write `Composer.tsx`**

Create `web/components/Composer.tsx`:

```tsx
"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CandidateList } from "@/components/CandidateList";
import { RatingChips } from "@/components/RatingChips";
import type { MediaCandidate } from "@/lib/catalog/types";
import {
  createPost,
  isRateLimited,
  ratingToPost,
  upsertMedia,
  type RatingChoice
} from "@/lib/compose";
import type { MediaKind } from "@/lib/media";
import { sanitizeCaption } from "@/lib/sanitize";
import { createClient } from "@/lib/supabase/client";

const KINDS: { kind: MediaKind; label: string }[] = [
  { kind: "movie", label: "Movies" },
  { kind: "show", label: "Shows" },
  { kind: "book", label: "Books" },
  { kind: "album", label: "Albums" }
];

const SEARCH_DEBOUNCE_MS = 350;

/**
 * The log flow, porting ComposerViewModel: search a catalog, pick something,
 * then either save it for later or rate and caption it.
 */
export function Composer({ userId }: { userId: string }) {
  const router = useRouter();
  const [kind, setKind] = useState<MediaKind>("movie");
  const [query, setQuery] = useState("");
  const [candidates, setCandidates] = useState<MediaCandidate[]>([]);
  const [searching, setSearching] = useState(false);
  const [picked, setPicked] = useState<MediaCandidate | null>(null);
  const [rating, setRating] = useState<RatingChoice | null>(null);
  const [caption, setCaption] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  // The effect owns only the debounced fetch; it writes state from the
  // timer callback, never synchronously in the body (React 19 forbids that).
  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed.length === 0) {
      setCandidates([]);
      return;
    }

    const timer = setTimeout(async () => {
      setSearching(true);
      try {
        const response = await fetch(
          `/api/catalog/search?kind=${kind}&q=${encodeURIComponent(trimmed)}`
        );
        const json = await response.json();
        if (!response.ok) throw new Error(json.error ?? "Search failed.");
        setCandidates(json.candidates ?? []);
        setError("");
      } catch (searchError) {
        setCandidates([]);
        setError(searchError instanceof Error ? searchError.message : "Search failed.");
      } finally {
        setSearching(false);
      }
    }, SEARCH_DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [query, kind]);

  async function submit(action: "log" | "watchlist") {
    if (!picked) return;
    setError("");

    let captionValue: string | null = null;
    if (action === "log" && caption.trim().length > 0) {
      const result = sanitizeCaption(caption);
      if (!result.valid) {
        setError("Captions max out at 500 characters.");
        return;
      }
      captionValue = result.value;
    }

    const { action: postAction, rating: numericRating } =
      action === "watchlist" ? { action: "saved" as const, rating: null } : ratingToPost(rating);

    setSubmitting(true);
    try {
      const supabase = createClient();
      const mediaId = await upsertMedia(supabase, picked);
      await createPost(supabase, {
        authorId: userId,
        mediaId,
        action: postAction,
        rating: numericRating,
        caption: captionValue
      });
      router.push("/feed");
      router.refresh();
    } catch (submitError) {
      setError(
        isRateLimited(submitError)
          ? "You're logging very fast — give it a moment."
          : "Couldn't save that. Please try again."
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (picked) {
    return (
      <div className="flex flex-col gap-4">
        <button
          type="button"
          onClick={() => setPicked(null)}
          className="self-start text-sm font-semibold text-(--color-text-secondary)"
        >
          ← Pick something else
        </button>

        <h1 className="text-xl font-semibold text-(--color-text-primary)">{picked.title}</h1>

        <RatingChips value={rating} onChange={setRating} />

        <textarea
          value={caption}
          onChange={(event) => setCaption(event.target.value)}
          placeholder="Add a note (optional)"
          rows={3}
          className="resize-none rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
        />

        {error && <p className="text-sm text-red-500">{error}</p>}

        <div className="flex gap-3">
          <button
            type="button"
            disabled={submitting}
            onClick={() => void submit("log")}
            className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
          >
            {submitting ? "Saving…" : "Log it"}
          </button>
          <button
            type="button"
            disabled={submitting}
            onClick={() => void submit("watchlist")}
            className="rounded-pill border border-(--color-separator) px-4 py-2 font-semibold text-(--color-text-primary) disabled:opacity-50"
          >
            Add to watchlist
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Log something</h1>

      <div className="flex gap-2">
        {KINDS.map((option) => (
          <button
            key={option.kind}
            type="button"
            aria-pressed={kind === option.kind}
            onClick={() => setKind(option.kind)}
            className={
              kind === option.kind
                ? "rounded-pill bg-(--color-accent) px-3 py-1.5 text-sm font-semibold text-(--color-on-accent)"
                : "rounded-pill border border-(--color-separator) px-3 py-1.5 text-sm text-(--color-text-primary)"
            }
          >
            {option.label}
          </button>
        ))}
      </div>

      <input
        type="text"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search"
        className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
      />

      {error && <p className="text-sm text-red-500">{error}</p>}

      {searching && candidates.length === 0 && (
        <p className="text-(--color-text-secondary)">Searching…</p>
      )}

      {!searching && query.trim().length > 0 && candidates.length === 0 && !error && (
        <p className="text-(--color-text-secondary)">Nothing found for that.</p>
      )}

      <CandidateList candidates={candidates} onPick={setPicked} />
    </div>
  );
}
```

- [ ] **Step 4: Write the page**

Create `web/app/(app)/composer/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { Composer } from "@/components/Composer";
import { createClient } from "@/lib/supabase/server";

export default async function ComposerPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col px-4 py-8">
      <Composer userId={user.id} />
    </main>
  );
}
```

- [ ] **Step 5: Add the nav entry**

In `web/components/AppNav.tsx`, replace the `TABS` constant and add a Log link before the closing `</ul>`:

```tsx
const TABS = [
  { href: "/feed", label: "Feed" },
  { href: null, label: "Explorer" },
  { href: "/profile", label: "Profile" }
] as const;
```

Then, immediately before `</ul>`, insert:

```tsx
<li>
  <Link
    href="/composer"
    className="rounded-pill bg-(--color-accent) px-3 py-1.5 text-sm font-semibold text-(--color-on-accent)"
  >
    Log
  </Link>
</li>
```

The existing AppNav test asserts the tab order is `["Feed", "Explorer", "Profile"]` by reading every list item; update that assertion to `["Feed", "Explorer", "Profile", "Log"]` — the wordmark item is already filtered out by that test.

- [ ] **Step 6: Verify everything**

Run: `cd web && npm run lint && npm run test && npm run build && npm run test:e2e`
Expected: all pass; the build lists `/composer` and `/api/catalog/search`.

- [ ] **Step 7: Commit**

```bash
git add web/components web/app/(app)/composer web/e2e/composer.spec.ts
git commit -m "feat(web): add the composer page and its nav entry"
```

---

### Task 8: Documentation

**Files:**

- Modify: `docs/TECH_DEBT.md`

- [ ] **Step 1: Resolve tech-debt row 16's dead end**

Row 16 records that a new web user with an empty feed has no in-app way out. The composer gives them one — logging something fills their own feed — but people search still doesn't exist, so the row is only half-resolved. Rewrite row 16's debt column to:

```markdown
| 16 | ~~A brand-new web user who follows nobody sees the empty feed with no in-app way out.~~ **PARTLY RESOLVED 2026-08-04:** the composer gives them an action — logging something fills their own feed. Finding _other people_ still has no web path until Explorer/people search ships, and the empty-state copy still omits iOS's "Find them under People in the Explorer tab" sentence. |
```

- [ ] **Step 2: Add the deployment requirement**

Append a row to the table:

```markdown
| 17 | `TMDB_API_KEY` must be set wherever web is deployed, or movie and show search returns a clear error while books and albums keep working. It is in `web/.env.local` for local development and is deliberately server-only (no `NEXT_PUBLIC_` prefix). | Web has no hosting yet — the Phase 1 spec planned Vercel's free tier and it was never set up, so there is nowhere to configure it. | Set it alongside the Supabase env vars when web is first deployed. CI does not need it: E2E tests never call the endpoint and the key is read per request, not at build time. |
```

- [ ] **Step 3: Format and commit**

```bash
npx --yes prettier@3.9.6 --write docs/TECH_DEBT.md
git add docs/TECH_DEBT.md
git commit -m "docs: record the composer's effect on the empty-feed dead end"
```

---

## Self-Review

**Spec coverage.** `/composer` page → Task 7. Search endpoint → Task 4. Catalog layer → Tasks 2, 3. Nav entry → Task 7. Write path + rating mapping → Task 5. `sanitizeCaption` → Task 5. Post rate limit → Task 1. Search rate limit → Task 4. Error copy (missing key, P0429, empty results) → Tasks 4, 7. Testing → Tasks 2, 3, 5, 6, 7. Deployment note → Task 8.

**Known gaps, deliberate.** The Route Handler's live network path is not covered end to end, matching how every other `lib/` fetcher is tested through its pure helpers; the authenticated-session fixture gap (tech-debt row 13) still blocks real E2E. Search is page 1 only, per the spec.

**Type consistency.** `MediaCandidate` (Task 2) is consumed with identical field names in Tasks 3, 5, 6, 7. `RatingChoice` and `ratingToPost` (Task 5) are used unchanged in Tasks 6 and 7. `upsertMedia(client, candidate)` and `createPost(client, options)` (Task 5) match their call sites in Task 7. `PostAction` is imported from `@/lib/feed`, where Phase 3 defined it.
