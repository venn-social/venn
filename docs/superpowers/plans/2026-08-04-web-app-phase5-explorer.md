# Web App Phase 5: Explorer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give web an Explorer with all six iOS categories, so a user can finally find other people to follow — the last dead end on web.

**Architecture:** People search runs a PostgREST `or(...)` filter over `profiles`, built through an injection-safe pattern ported verbatim from iOS. Media search reuses the composer's existing `/api/catalog/search`; browse reads recent `media` rows. Every result row and tile already exists from Phases 3 and 4.

**Tech Stack:** Next.js 16 (App Router), `@supabase/supabase-js`, Tailwind v4, Vitest, React Testing Library, Playwright.

## Global Constraints

- Node 24 (`.nvmrc`) — run `nvm use` in `web/` before any command.
- Design tokens only: the `--color-*` vars in `app/globals.css` and Tailwind's numeric spacing scale. **Never** add a named `--spacing-*` key.
- Copy mirrors `ExplorerView.swift` verbatim except the one approved deviation in Task 5 ("Recently added" instead of "Recommended for you").
- **No new migration** — `explorer` and `search` are already reserved usernames.
- `containsPattern` is security-critical: it prevents PostgREST filter injection. Port its character policy exactly; do not "simplify" it.
- No `next/image` — plain `<img loading="lazy">`.
- Format markdown with the lockfile-pinned prettier (`npx prettier@3.9.6`), never the local binary.
- All work stays on branch `feat/web-explorer`.

## File Structure

| File                               | Responsibility                          |
| ---------------------------------- | --------------------------------------- |
| `web/lib/people.ts`                | Injection-safe pattern + profile search |
| `web/lib/explore.ts`               | Recent catalog media by kind            |
| `web/components/CategoryChips.tsx` | The six category chips                  |
| `web/components/Explorer.tsx`      | Category + query state, result routing  |
| `web/app/(app)/explorer/page.tsx`  | Auth-gated route                        |
| `web/components/Composer.tsx`      | Accept `?kind=`/`?q=` prefill           |
| `web/components/AppNav.tsx`        | Explorer becomes a real link            |

---

### Task 1: `sanitizeSearchQuery` + `lib/people.ts`

**Files:**

- Modify: `web/lib/sanitize.ts`
- Create: `web/lib/people.ts`
- Test: `web/lib/__tests__/people.test.ts`, plus cases in `web/lib/__tests__/sanitize.test.ts`

**Interfaces:**

- Consumes: `normalise`, `SanitizeResult` from `@/lib/sanitize`; `toUserProfile`, `ProfileRow`, `UserProfile` from `@/lib/profile`.
- Produces: `sanitizeSearchQuery(input: string): SanitizeResult`; `containsPattern(query: string): string`; `searchProfiles(client, query, limit?): Promise<UserProfile[]>`.

`containsPattern` is the security-critical function in this phase — see the spec's "The security-critical part".

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/people.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { containsPattern } from "@/lib/people";

describe("containsPattern", () => {
  it("wraps a plain term in contains wildcards", () => {
    expect(containsPattern("ada")).toBe("*ada*");
  });

  it("keeps the username alphabet", () => {
    expect(containsPattern("ada_love-lace9")).toBe("*ada_love-lace9*");
  });

  it("keeps accented letters", () => {
    expect(containsPattern("José")).toBe("*José*");
  });

  it("strips characters PostgREST treats as filter syntax", () => {
    // Commas separate conditions, dots separate column.operator.value,
    // parens group, quotes delimit — any of these would corrupt the
    // or(...) string this feeds into.
    expect(containsPattern("a,b.c(d)e'f\"g")).toBe("*abcdefg*");
  });

  it("strips wildcards so a user can't widen their own match", () => {
    expect(containsPattern("a*b%c")).toBe("*abc*");
  });

  it("collapses internal whitespace and trims the edges", () => {
    expect(containsPattern("  ada   lovelace  ")).toBe("*ada lovelace*");
  });

  it("returns an empty string when nothing searchable survives", () => {
    // The caller must treat this as "no results" and issue no query.
    expect(containsPattern("...")).toBe("");
    expect(containsPattern("")).toBe("");
    expect(containsPattern("   ")).toBe("");
  });
});
```

Add to `web/lib/__tests__/sanitize.test.ts` (import `sanitizeSearchQuery` with the others):

```ts
describe("sanitizeSearchQuery", () => {
  it("accepts a normal query", () => {
    expect(sanitizeSearchQuery("ada")).toEqual({ valid: true, value: "ada" });
  });

  it("accepts an empty query — an empty search box isn't an error", () => {
    expect(sanitizeSearchQuery("")).toEqual({ valid: true, value: "" });
  });

  it("accepts a query at exactly 100 characters", () => {
    expect(sanitizeSearchQuery("a".repeat(100))).toEqual({ valid: true, value: "a".repeat(100) });
  });

  it("rejects a query over 100 characters", () => {
    expect(sanitizeSearchQuery("a".repeat(101))).toEqual({ valid: false, reason: "tooLong" });
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- people sanitize`
Expected: FAIL — `Cannot find module '@/lib/people'`.

- [ ] **Step 3: Add `sanitizeSearchQuery`**

In `web/lib/sanitize.ts`, add after `sanitizeCaption`:

```ts
/**
 * Search query. Optional (empty is valid — an empty box isn't an error),
 * max 100 chars after normalise. Mirrors Sanitize.searchQuery.
 */
export function sanitizeSearchQuery(input: string): SanitizeResult {
  const normalised = normalise(input);
  if (normalised.length > 100) return { valid: false, reason: "tooLong" };
  return { valid: true, value: normalised };
}
```

- [ ] **Step 4: Write `lib/people.ts`**

Create `web/lib/people.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

/**
 * Build a PostgREST contains-pattern (`*term*`) from raw input.
 *
 * SECURITY: the result is interpolated into a raw `or(...)` filter string
 * that PostgREST parses itself. In that string commas separate conditions,
 * dots separate column/operator/value, parens group, and quotes delimit —
 * all syntax. `*` and `%` are multi-character wildcards. Untrusted
 * characters would corrupt the filter or widen the match arbitrarily, so
 * only letters, digits, spaces, `_`, and `-` survive.
 *
 * `_` is kept despite being a single-character LIKE wildcard: it's part of
 * the username alphabet and still matches itself, so the worst case is a
 * benign over-match.
 *
 * Returns "" when nothing searchable remains — callers must treat that as
 * "no results" and issue no query. Ports PeopleSearchService.containsPattern.
 */
export function containsPattern(query: string): string {
  const kept = [...query].filter((character) => /[\p{L}\p{Nd} _-]/u.test(character)).join("");
  const term = kept.replace(/\s+/g, " ").trim();
  return term.length === 0 ? "" : `*${term}*`;
}

/** Mirrors PeopleSearchService.searchProfiles. */
export async function searchProfiles(
  client: SupabaseClient,
  query: string,
  limit = 20
): Promise<UserProfile[]> {
  const pattern = containsPattern(query);
  if (pattern === "") return [];

  const { data, error } = await client
    .from("profiles")
    .select()
    .or(`username.ilike.${pattern},display_name.ilike.${pattern}`)
    .order("username", { ascending: true })
    .limit(limit);

  if (error) throw error;
  return ((data ?? []) as ProfileRow[]).map(toUserProfile);
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd web && npm run test -- people sanitize`
Expected: PASS — 7 pattern tests plus 4 query tests green.

- [ ] **Step 6: Commit**

```bash
git add web/lib/people.ts web/lib/sanitize.ts web/lib/__tests__/people.test.ts web/lib/__tests__/sanitize.test.ts
git commit -m "feat(web): add injection-safe people search"
```

---

### Task 2: `lib/explore.ts`

**Files:**

- Create: `web/lib/explore.ts`
- Test: `web/lib/__tests__/explore.test.ts`

**Interfaces:**

- Consumes: `toMedia`, `Media`, `MediaKind`, `MediaRow` from `@/lib/media`.
- Produces: `fetchRecentMedia(client, kind, limit?): Promise<Media[]>`; `toMediaList(rows: unknown): Media[]`.

Ports `ExplorerService.recentMedia`, reusing the shared decoder rather than adding a third copy.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/explore.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { toMediaList } from "@/lib/explore";

describe("toMediaList", () => {
  it("maps rows into domain media", () => {
    const media = toMediaList([
      {
        id: "m1",
        kind: "movie",
        title: "Past Lives",
        year: 2023,
        primary_creator: "Celine Song",
        cover_url: null
      }
    ]);

    expect(media).toHaveLength(1);
    expect(media[0].title).toBe("Past Lives");
    expect(media[0].kind).toBe("movie");
  });

  it("drops rows with an unknown kind rather than breaking the grid", () => {
    const media = toMediaList([
      { id: "m1", kind: "hologram", title: "Weird" },
      { id: "m2", kind: "book", title: "Fine" }
    ]);

    expect(media.map((item) => item.title)).toEqual(["Fine"]);
  });

  it("returns an empty array for null or a non-array", () => {
    expect(toMediaList(null)).toEqual([]);
    expect(toMediaList(undefined)).toEqual([]);
    expect(toMediaList({})).toEqual([]);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- explore`
Expected: FAIL — `Cannot find module '@/lib/explore'`.

- [ ] **Step 3: Write the implementation**

Create `web/lib/explore.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { toMedia, type Media, type MediaKind, type MediaRow } from "@/lib/media";

/** Shared decoder — unknown kinds drop out rather than breaking the grid. */
export function toMediaList(rows: unknown): Media[] {
  if (!Array.isArray(rows)) return [];
  return (rows as MediaRow[]).map(toMedia).filter((media): media is Media => media !== null);
}

/**
 * Newest catalog media of one kind. Ports ExplorerService.recentMedia.
 *
 * This is what the browse panel shows. It is deliberately unranked: there
 * is no recommendation score yet, and none can exist until there's a follow
 * graph and interaction history to compute one from. The signature is the
 * shape a scored version would keep, so that becomes an implementation
 * change rather than an API change.
 */
export async function fetchRecentMedia(
  client: SupabaseClient,
  kind: MediaKind,
  limit = 20
): Promise<Media[]> {
  const { data, error } = await client
    .from("media")
    .select("*")
    .eq("kind", kind)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return toMediaList(data);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- explore`
Expected: PASS — 3 tests green.

- [ ] **Step 5: Commit**

```bash
git add web/lib/explore.ts web/lib/__tests__/explore.test.ts
git commit -m "feat(web): add recent-catalog browse for Explorer"
```

---

### Task 3: `CategoryChips.tsx`

**Files:**

- Create: `web/components/CategoryChips.tsx`
- Test: `web/components/__tests__/CategoryChips.test.tsx`

**Interfaces:**

- Consumes: `MediaKind` from `@/lib/media`.
- Produces: `type ExploreCategory = "all" | "people" | "movies" | "tv" | "music" | "books"`; `CATEGORIES: { category: ExploreCategory; label: string }[]`; `searchKindsFor(category)`; `browseKindFor(category)`; `<CategoryChips value onChange />`.

Ports `ExplorerCategory.swift` — same six cases, same titles, same `searchKinds`/`browseKind` mapping.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/CategoryChips.test.tsx`:

```tsx
import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { browseKindFor, CategoryChips, searchKindsFor } from "@/components/CategoryChips";

describe("category mapping", () => {
  it("searches every media kind for All", () => {
    expect(searchKindsFor("all")).toEqual(["movie", "show", "album", "book"]);
  });

  it("searches no media kinds for People", () => {
    // People search goes through profiles, not the media catalog.
    expect(searchKindsFor("people")).toEqual([]);
  });

  it("maps each media category to its one kind", () => {
    expect(searchKindsFor("movies")).toEqual(["movie"]);
    expect(searchKindsFor("tv")).toEqual(["show"]);
    expect(searchKindsFor("music")).toEqual(["album"]);
    expect(searchKindsFor("books")).toEqual(["book"]);
  });

  it("has no browse kind for All or People", () => {
    expect(browseKindFor("all")).toBeNull();
    expect(browseKindFor("people")).toBeNull();
  });

  it("browses the matching kind for media categories", () => {
    expect(browseKindFor("movies")).toBe("movie");
    expect(browseKindFor("tv")).toBe("show");
  });
});

describe("CategoryChips", () => {
  it("renders all six categories with iOS's titles", () => {
    render(<CategoryChips value="all" onChange={() => {}} />);
    for (const label of ["All", "People", "Movies", "TV", "Music", "Books"]) {
      expect(screen.getByRole("button", { name: label })).toBeDefined();
    }
  });

  it("reports the selected category", () => {
    const onChange = vi.fn();
    render(<CategoryChips value="all" onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", { name: "People" }));
    expect(onChange).toHaveBeenCalledWith("people");
  });

  it("marks the current category as pressed", () => {
    render(<CategoryChips value="books" onChange={() => {}} />);
    expect(screen.getByRole("button", { name: "Books" }).getAttribute("aria-pressed")).toBe("true");
    expect(screen.getByRole("button", { name: "All" }).getAttribute("aria-pressed")).toBe("false");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- CategoryChips`
Expected: FAIL — cannot find `@/components/CategoryChips`.

- [ ] **Step 3: Write the implementation**

Create `web/components/CategoryChips.tsx`:

```tsx
"use client";

import type { MediaKind } from "@/lib/media";

/** Ports ExplorerCategory.swift — same six cases, same titles. */
export type ExploreCategory = "all" | "people" | "movies" | "tv" | "music" | "books";

export const CATEGORIES: { category: ExploreCategory; label: string }[] = [
  { category: "all", label: "All" },
  { category: "people", label: "People" },
  { category: "movies", label: "Movies" },
  { category: "tv", label: "TV" },
  { category: "music", label: "Music" },
  { category: "books", label: "Books" }
];

/** Media kinds this category searches. Empty for People — that goes to profiles. */
export function searchKindsFor(category: ExploreCategory): MediaKind[] {
  switch (category) {
    case "all":
      return ["movie", "show", "album", "book"];
    case "movies":
      return ["movie"];
    case "tv":
      return ["show"];
    case "music":
      return ["album"];
    case "books":
      return ["book"];
    default:
      return [];
  }
}

/** The single kind the browse panel loads. Null for All and People. */
export function browseKindFor(category: ExploreCategory): MediaKind | null {
  const kinds = searchKindsFor(category);
  return category === "all" || kinds.length !== 1 ? null : kinds[0];
}

interface CategoryChipsProps {
  value: ExploreCategory;
  onChange: (next: ExploreCategory) => void;
}

export function CategoryChips({ value, onChange }: CategoryChipsProps) {
  return (
    <div className="flex flex-wrap gap-2">
      {CATEGORIES.map(({ category, label }) => {
        const selected = value === category;
        return (
          <button
            key={category}
            type="button"
            aria-pressed={selected}
            onClick={() => onChange(category)}
            className={
              selected
                ? "rounded-pill bg-(--color-accent) px-3 py-1.5 text-sm font-semibold text-(--color-on-accent)"
                : "rounded-pill border border-(--color-separator) px-3 py-1.5 text-sm text-(--color-text-primary)"
            }
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- CategoryChips`
Expected: PASS — 8 tests green.

- [ ] **Step 5: Commit**

```bash
git add web/components/CategoryChips.tsx web/components/__tests__/CategoryChips.test.tsx
git commit -m "feat(web): add Explorer category chips"
```

---

### Task 4: Composer prefill

**Files:**

- Modify: `web/components/Composer.tsx`, `web/app/(app)/composer/page.tsx`
- Test: add a case to `web/components/__tests__/Composer.test.tsx`

**Interfaces:**

- Produces: `<Composer userId initialKind? initialQuery? />`.

Read once as initial state, not synced on every change — the composer's state machine stays exactly as it is.

- [ ] **Step 1: Write the failing test**

Add to `web/components/__tests__/Composer.test.tsx`:

```tsx
it("starts from the kind and query it was given", async () => {
  render(<Composer userId="u1" initialKind="book" initialQuery="piranesi" />);

  expect(screen.getByDisplayValue("piranesi")).toBeDefined();
  expect(screen.getByRole("button", { name: "Books" }).getAttribute("aria-pressed")).toBe("true");
  // The prefilled query searches immediately, without retyping.
  expect(await screen.findByRole("button", { name: /Past Lives/ })).toBeDefined();
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd web && npm run test -- Composer`
Expected: FAIL — the query field is empty and Movies is still selected.

- [ ] **Step 3: Accept the props**

In `web/components/Composer.tsx`, change the signature and the two initial `useState` calls:

```tsx
export function Composer({
  userId,
  initialKind = "movie",
  initialQuery = ""
}: {
  userId: string;
  initialKind?: MediaKind;
  initialQuery?: string;
}) {
  const router = useRouter();
  const [kind, setKind] = useState<MediaKind>(initialKind);
  const [query, setQuery] = useState(initialQuery);
```

Leave every other line of the component unchanged.

- [ ] **Step 4: Pass them through from the page**

Replace the body of `web/app/(app)/composer/page.tsx`'s return with a version that reads search params:

```tsx
import { redirect } from "next/navigation";
import { Composer } from "@/components/Composer";
import { MEDIA_KINDS, type MediaKind } from "@/lib/media";
import { createClient } from "@/lib/supabase/server";

interface ComposerPageProps {
  searchParams: Promise<{ kind?: string; q?: string }>;
}

export default async function ComposerPage({ searchParams }: ComposerPageProps) {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  // Explorer links here with a prefill; anything unrecognised falls back to
  // the default rather than putting the composer in an impossible state.
  const { kind, q } = await searchParams;
  const initialKind = kind && MEDIA_KINDS.includes(kind) ? (kind as MediaKind) : undefined;

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col px-4 py-8">
      <Composer userId={user.id} initialKind={initialKind} initialQuery={q ?? ""} />
    </main>
  );
}
```

- [ ] **Step 5: Verify**

Run: `cd web && npm run test -- Composer && npm run build`
Expected: tests PASS; build succeeds.

- [ ] **Step 6: Commit**

```bash
git add web/components/Composer.tsx web/app/(app)/composer/page.tsx web/components/__tests__/Composer.test.tsx
git commit -m "feat(web): let the composer start from a kind and query"
```

---

### Task 5: `Explorer.tsx` + the route + the nav link

**Files:**

- Create: `web/components/Explorer.tsx`, `web/app/(app)/explorer/page.tsx`
- Modify: `web/components/AppNav.tsx`, `web/components/__tests__/AppNav.test.tsx`
- Test: `web/components/__tests__/Explorer.test.tsx`, `web/e2e/explorer.spec.ts`

**Interfaces:**

- Consumes: everything from Tasks 1–3; `ProfileRow` (Phase 3), `CandidateList` and `MediaCover` (Phases 3–4).
- Produces: the `/explorer` route.

**Copy**, from `ExplorerView.swift` verbatim except where noted:

- Search field placeholder: `Search movies, TV, music, books, people`
- People prompt: **Find your people** / `Search by name or username to see what they're into.`
- All prompt: **Search everything** / `Type in the search bar to find movies, TV shows, music, and books all at once.`
- No people found: **No one found** / `Try a different name or username.`
- Empty catalog: **Nothing here yet** / `Search to find something to log.` — iOS says "We don't have any X in the catalog yet."; web adds the pointer because the catalog is empty today and search is the action that works.
- Browse heading: **Recently added** — deviates from iOS's "Recommended for you" because nothing is ranked. See the spec.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/Explorer.test.tsx`:

```tsx
import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Explorer } from "@/components/Explorer";

const push = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push }) }));
vi.mock("@/lib/supabase/client", () => ({ createClient: () => ({}) }));

const { searchProfiles, fetchRecentMedia } = vi.hoisted(() => ({
  searchProfiles: vi.fn(),
  fetchRecentMedia: vi.fn()
}));

vi.mock("@/lib/people", async () => {
  const actual = await vi.importActual<typeof import("@/lib/people")>("@/lib/people");
  return { ...actual, searchProfiles };
});
vi.mock("@/lib/explore", async () => {
  const actual = await vi.importActual<typeof import("@/lib/explore")>("@/lib/explore");
  return { ...actual, fetchRecentMedia };
});

const person = {
  id: "u2",
  username: "maya",
  displayName: "Maya Okonkwo",
  avatarUrl: null,
  bio: null,
  isPrivate: false,
  createdAt: "2026-01-01T00:00:00Z"
};

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
  push.mockReset();
  searchProfiles.mockReset().mockResolvedValue([person]);
  fetchRecentMedia.mockReset().mockResolvedValue([]);
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => ({ ok: true, json: async () => ({ candidates: [candidate] }) }))
  );
});

describe("Explorer", () => {
  it("prompts for a search before anything is typed", () => {
    render(<Explorer />);
    expect(screen.getByText("Search everything")).toBeDefined();
  });

  it("shows the People prompt when that category is selected", () => {
    render(<Explorer />);
    fireEvent.click(screen.getByRole("button", { name: "People" }));
    expect(screen.getByText("Find your people")).toBeDefined();
  });

  it("finds people and links each to their profile", async () => {
    render(<Explorer />);
    fireEvent.click(screen.getByRole("button", { name: "People" }));
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), { target: { value: "maya" } });

    const link = await screen.findByRole("link", { name: /Maya Okonkwo/ });
    expect(link.getAttribute("href")).toBe("/maya");
  });

  it("says so when nobody matches", async () => {
    searchProfiles.mockResolvedValue([]);
    render(<Explorer />);
    fireEvent.click(screen.getByRole("button", { name: "People" }));
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), { target: { value: "zzz" } });

    expect(await screen.findByText("No one found")).toBeDefined();
  });

  it("sends a picked media result to the composer with a prefill", async () => {
    render(<Explorer />);
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), {
      target: { value: "past lives" }
    });

    fireEvent.click(await screen.findByRole("button", { name: /Past Lives/ }));

    await waitFor(() => expect(push).toHaveBeenCalled());
    expect(push.mock.calls[0][0]).toBe("/composer?kind=movie&q=Past+Lives");
  });

  it("shows the empty-catalog state when a category has nothing to browse", async () => {
    render(<Explorer />);
    fireEvent.click(screen.getByRole("button", { name: "Movies" }));
    expect(await screen.findByText("Nothing here yet")).toBeDefined();
  });
});
```

Create `web/e2e/explorer.spec.ts`:

```ts
import { expect, test } from "@playwright/test";

test("visiting /explorer while signed out redirects to /login", async ({ page }) => {
  await page.goto("/explorer");
  await expect(page).toHaveURL(/\/login/);
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- Explorer`
Expected: FAIL — cannot find `@/components/Explorer`.

- [ ] **Step 3: Write `Explorer.tsx`**

Create `web/components/Explorer.tsx`:

```tsx
"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CandidateList } from "@/components/CandidateList";
import {
  browseKindFor,
  CategoryChips,
  searchKindsFor,
  type ExploreCategory
} from "@/components/CategoryChips";
import { MediaCover } from "@/components/MediaCover";
import { ProfileRow } from "@/components/ProfileRow";
import type { MediaCandidate } from "@/lib/catalog/types";
import { fetchRecentMedia } from "@/lib/explore";
import type { Media } from "@/lib/media";
import { searchProfiles } from "@/lib/people";
import type { UserProfile } from "@/lib/profile";
import { createClient } from "@/lib/supabase/client";

const SEARCH_DEBOUNCE_MS = 350;

/** Ports ExplorerView.swift: category chips over a search field. */
export function Explorer() {
  const router = useRouter();
  const [category, setCategory] = useState<ExploreCategory>("all");
  const [query, setQuery] = useState("");
  const [people, setPeople] = useState<UserProfile[]>([]);
  const [candidates, setCandidates] = useState<MediaCandidate[]>([]);
  const [browse, setBrowse] = useState<Media[]>([]);
  const [searching, setSearching] = useState(false);
  const [error, setError] = useState("");

  const trimmed = query.trim();
  // Derived: an empty query means "show nothing" whatever the last search
  // returned. Clearing it inside the effect would be a synchronous setState
  // in an effect body, which React 19's set-state-in-effect rule rejects.
  const visiblePeople = trimmed.length === 0 ? [] : people;
  const visibleCandidates = trimmed.length === 0 ? [] : candidates;
  const browseKind = browseKindFor(category);

  // Browse panel: only for the four single-kind categories.
  useEffect(() => {
    if (!browseKind) return;
    let cancelled = false;

    fetchRecentMedia(createClient(), browseKind)
      .then((media) => {
        if (!cancelled) setBrowse(media);
      })
      .catch(() => {
        if (!cancelled) setBrowse([]);
      });

    return () => {
      cancelled = true;
    };
  }, [browseKind]);

  // Search. The effect owns only the debounced fetch.
  useEffect(() => {
    const term = query.trim();
    if (term.length === 0) return;

    const timer = setTimeout(async () => {
      setSearching(true);
      setError("");
      try {
        if (category === "people") {
          setPeople(await searchProfiles(createClient(), term));
          setCandidates([]);
        } else {
          const kinds = searchKindsFor(category);
          const responses = await Promise.all(
            kinds.map((kind) =>
              fetch(`/api/catalog/search?kind=${kind}&q=${encodeURIComponent(term)}`).then(
                (response) => response.json()
              )
            )
          );
          setCandidates(responses.flatMap((json) => json.candidates ?? []));
          setPeople([]);
        }
      } catch {
        setError("Search failed.");
        setPeople([]);
        setCandidates([]);
      } finally {
        setSearching(false);
      }
    }, SEARCH_DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [query, category]);

  function openComposer(candidate: MediaCandidate) {
    const params = new URLSearchParams({ kind: candidate.kind, q: candidate.title });
    router.push(`/composer?${params.toString()}`);
  }

  return (
    <div className="flex flex-col gap-4">
      <CategoryChips value={category} onChange={setCategory} />

      <input
        type="text"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search movies, TV, music, books, people"
        className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
      />

      {error && <p className="text-sm text-red-500">{error}</p>}
      {searching && <p className="text-(--color-text-secondary)">Searching…</p>}

      {trimmed.length === 0 && category === "people" && (
        <Prompt
          title="Find your people"
          message="Search by name or username to see what they're into."
        />
      )}

      {trimmed.length === 0 && category === "all" && (
        <Prompt
          title="Search everything"
          message="Type in the search bar to find movies, TV shows, music, and books all at once."
        />
      )}

      {trimmed.length === 0 && browseKind && (
        <section className="flex flex-col gap-3">
          <h2 className="font-semibold text-(--color-text-primary)">Recently added</h2>
          {browse.length === 0 ? (
            <Prompt title="Nothing here yet" message="Search to find something to log." />
          ) : (
            <ul className="grid grid-cols-3 gap-2">
              {browse.map((media) => (
                <li key={media.id}>
                  <MediaCover media={media} />
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      {category === "people" && trimmed.length > 0 && !searching && (
        <>
          {visiblePeople.length === 0 ? (
            <Prompt title="No one found" message="Try a different name or username." />
          ) : (
            <ul className="flex flex-col divide-y divide-(--color-separator)">
              {visiblePeople.map((profile) => (
                <li key={profile.id}>
                  <ProfileRow profile={profile} />
                </li>
              ))}
            </ul>
          )}
        </>
      )}

      {category !== "people" && (
        <CandidateList candidates={visibleCandidates} onPick={openComposer} />
      )}
    </div>
  );
}

function Prompt({ title, message }: { title: string; message: string }) {
  return (
    <div className="flex flex-col gap-1 py-6 text-center">
      <p className="font-semibold text-(--color-text-primary)">{title}</p>
      <p className="text-(--color-text-secondary)">{message}</p>
    </div>
  );
}
```

- [ ] **Step 4: Write the page**

Create `web/app/(app)/explorer/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { Explorer } from "@/components/Explorer";
import { createClient } from "@/lib/supabase/server";

export default async function ExplorerPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col px-4 py-8">
      <Explorer />
    </main>
  );
}
```

- [ ] **Step 5: Make Explorer a real nav link**

In `web/components/AppNav.tsx`, change the Explorer entry from `{ href: null, label: "Explorer" }` to `{ href: "/explorer", label: "Explorer" }`, and delete the `if (tab.href === null)` branch that rendered the disabled span — no tab is disabled any more.

In `web/components/__tests__/AppNav.test.tsx`, replace the disabled-Explorer test with:

```tsx
it("links Explorer now that the route exists", () => {
  render(<AppNav />);
  expect(screen.getByRole("link", { name: "Explorer" }).getAttribute("href")).toBe("/explorer");
});
```

- [ ] **Step 6: Verify everything**

Run: `cd web && npm run lint && npm run test && npm run build && npm run test:e2e`
Expected: all pass; the build lists `/explorer`.

- [ ] **Step 7: Commit**

```bash
git add web/components web/app/(app)/explorer web/e2e/explorer.spec.ts
git commit -m "feat(web): add Explorer with people and media search"
```

---

### Task 6: Documentation

**Files:**

- Modify: `docs/TECH_DEBT.md`

- [ ] **Step 1: Close row 16**

Explorer removes the last dead end. Replace row 16's debt column with:

```markdown
| 16 | ~~A brand-new web user who follows nobody sees the empty feed with no in-app way out.~~ **RESOLVED 2026-08-04:** the composer lets them log something, and Explorer's People search lets them find and follow others. Web's feed empty state still omits iOS's "Find them under People in the Explorer tab — or log something yourself." sentence; restoring it is a one-line copy change now that both surfaces exist. |
```

- [ ] **Step 2: Record the browse-label deviation**

Append a row:

```markdown
| 18 | iOS's Explorer labels its browse panel "Recommended for you", but `ExplorerService.recentMedia` returns the newest catalog rows with no scoring. Web says "Recently added" instead, so the two platforms' copy differs (rule 17). | Matching the copy would ship a claim the code doesn't support — there is no recommendation engine on either platform, and none can exist until there's a follow graph and interaction history to compute one from. | When real ranking lands, iOS's label becomes true and web's should change to match. `fetchRecentMedia`'s signature is already the shape a scored version would keep. |
```

- [ ] **Step 3: Add the Figma backlog entry**

Under the Figma backlog list, add:

```markdown
- Web `/explorer` — category chips, search field, people result rows, media result rows, and the "Recently added" browse grid with its empty state
```

- [ ] **Step 4: Format and commit**

```bash
npx --yes prettier@3.9.6 --write docs/TECH_DEBT.md
git add docs/TECH_DEBT.md
git commit -m "docs: close the empty-feed dead end and record the browse-label deviation"
```

---

## Self-Review

**Spec coverage.** `/explorer` route → Task 5. Six categories → Task 3. People search + injection-safe pattern → Task 1. `sanitizeSearchQuery` → Task 1. Catalog browse → Task 2. Media search reusing `/api/catalog/search` → Task 5. Composer prefill → Task 4. Nav link → Task 5. Copy and the "Recently added" deviation → Tasks 5, 6. Testing → every task.

**Known gaps, deliberate.** Signed-in behaviour is still component-tested rather than end-to-end (tech-debt row 13). Search results are capped at 20 with no pagination, matching iOS. `searchProfiles`' network path is untested directly; `containsPattern`, the part that matters for security, is tested thoroughly.

**Type consistency.** `ExploreCategory`, `searchKindsFor`, `browseKindFor` (Task 3) are used with identical names in Task 5. `containsPattern`/`searchProfiles` (Task 1) and `fetchRecentMedia`/`toMediaList` (Task 2) match their call sites in Task 5. `Composer`'s new optional props (Task 4) match the page that passes them. `MEDIA_KINDS` is imported from `@/lib/media`, where Phase 3 defined and exported it.
