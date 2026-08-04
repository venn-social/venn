# Web App Phase 3: Feed + Navigation Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the web app a feed at `/feed`, the navigation shell needed to reach it, and a shared avatar component — closing the "photo uploaded but never displayed" gap.

**Architecture:** A Server Component renders the feed's first page; a small Client Component takes over for keyset-cursor infinite scroll via IntersectionObserver. Pages are regrouped into `(app)` (with nav) and `(auth)` (without) route groups — route groups do not change URLs. Every data function in `lib/` wraps the same tables iOS already reads.

**Tech Stack:** Next.js 16 (App Router, TypeScript), `@supabase/supabase-js`, Tailwind v4, Vitest, React Testing Library, Playwright.

## Global Constraints

- Node 24 (`.nvmrc`) — run `nvm use` in `web/` before any command in this plan.
- Design tokens: use the existing `--color-*` CSS vars in `app/globals.css` and Tailwind's native numeric spacing scale. **Never** add a named `--spacing-*` key — Tailwind v4 resolves `max-w-*`/`h-*` against `--spacing-*` before `--container-*`, so a named key silently hijacks unrelated sizing utilities (see the comment in `globals.css`).
- Copy mirrors the iOS source referenced in each task, per CLAUDE.md rule 17, with one approved deviation documented in Task 7.
- No `next/image` — plain `<img loading="lazy">` with explicit `width`/`height`. Adding remote hosts to `next.config.ts` is out of scope and Vercel bills per image transformation.
- The migration in Task 1 is **written but NOT applied** — do not run `npm run db:push`.
- All work stays on the single branch `feat/web-phase3-feed`.
- Run `npm run test` after every task touching `lib/` or `components/`; `npm run build` after any task touching `app/`. Format markdown with the lockfile-pinned prettier (`npx prettier@3.9.6`), never the possibly-stale local binary.

## File Structure

| File                                   | Responsibility                                  |
| -------------------------------------- | ----------------------------------------------- |
| `supabase/migrations/*_reserved_*.sql` | Extend the reserved-username CHECK constraint   |
| `web/lib/relativeTime.ts`              | "now"/"5m"/"2h" labels — pure                   |
| `web/lib/feed.ts`                      | Feed row types, row→domain mapping, paged fetch |
| `web/components/Avatar.tsx`            | Avatar image with initial fallback              |
| `web/components/FeedRow.tsx`           | One feed entry                                  |
| `web/components/FeedPagination.tsx`    | Client-side infinite scroll                     |
| `web/components/AppNav.tsx`            | Feed / Explorer / Profile nav                   |
| `web/app/(app)/layout.tsx`             | Authenticated shell — renders AppNav            |
| `web/app/(app)/feed/page.tsx`          | Feed page — first page, server-rendered         |

---

### Task 1: Reserved-usernames migration

**Files:**

- Create: `supabase/migrations/20260804120000_reserve_route_usernames.sql`
- Modify: `web/lib/onboarding.ts` (the `RESERVED_USERNAMES` set)
- Test: `web/lib/__tests__/onboarding.test.ts` (add a case)

**Interfaces:**

- Consumes: nothing.
- Produces: no new exports; `RESERVED_USERNAMES` gains entries.

`/feed` becomes a static top-level route, and Next.js resolves static routes over the dynamic `/[username]`, so a user named `feed` would be permanently unable to see their own profile. Verified against the live DB on 2026-08-04: no profile currently holds any name in this list, so the constraint cannot fail on existing rows.

- [ ] **Step 1: Write the migration**

Create `supabase/migrations/20260804120000_reserve_route_usernames.sql`:

```sql
-- =============================================================================
-- 20260804120000_reserve_route_usernames.sql — extend reserved usernames.
-- =============================================================================
-- Supersedes the list in 20260731090000_reserved_usernames.sql. Public
-- profiles are served at the top-level `/[username]` route, and Next.js
-- always resolves a static route over a dynamic one at the same level, so a
-- username matching a static top-level segment under web/app/ permanently
-- shadows that user's own profile.
--
-- Phase 3 adds `feed`. The remaining names are reserved ahead of the routes
-- that the phase roadmap already commits to (explorer/search in the Explorer
-- phase, composer in the Composer phase, settings with profile settings),
-- so each later phase does not need its own migration. Reserving a name is
-- cheap; reclaiming one after a user takes it is not.
--
-- Verified 2026-08-04: no existing profile holds any of these names, so
-- adding the constraint cannot fail on existing rows.
--
-- Idempotent: safe to replay (DROP CONSTRAINT IF EXISTS / ADD CONSTRAINT).
-- =============================================================================

alter table public.profiles
  drop constraint if exists profiles_username_not_reserved,
  add constraint profiles_username_not_reserved check (
    username not in (
      'auth', 'login', 'profile', 'requests',
      'feed', 'explorer', 'search', 'settings',
      'composer', 'notifications', 'about', 'terms', 'privacy'
    )
  );
```

- [ ] **Step 2: Update the client-side list**

In `web/lib/onboarding.ts`, replace the `RESERVED_USERNAMES` declaration:

```ts
/**
 * Usernames that would shadow a static route under web/app/ (see
 * supabase/migrations/20260804120000_reserve_route_usernames.sql). Checked
 * client-side too so the live availability indicator doesn't show
 * "available" for a name the DB constraint would then reject at submit.
 * This list and the CHECK constraint must change together.
 */
const RESERVED_USERNAMES = new Set([
  "auth",
  "login",
  "profile",
  "requests",
  "feed",
  "explorer",
  "search",
  "settings",
  "composer",
  "notifications",
  "about",
  "terms",
  "privacy"
]);
```

- [ ] **Step 3: Add a test case**

In `web/lib/__tests__/onboarding.test.ts`, inside the `isUsernameAvailable` describe block, add:

```ts
it("reports every route-shadowing username as unavailable without a query", async () => {
  const client = { from: vi.fn() } as unknown as SupabaseClient;
  for (const reserved of ["feed", "explorer", "settings", "composer"]) {
    expect(await isUsernameAvailable(client, reserved)).toBe(false);
  }
  expect(client.from).not.toHaveBeenCalled();
});
```

- [ ] **Step 4: Run the tests**

Run: `cd web && npm run test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/20260804120000_reserve_route_usernames.sql web/lib/onboarding.ts web/lib/__tests__/onboarding.test.ts
git commit -m "feat(web): reserve route-shadowing usernames"
```

---

### Task 2: `lib/relativeTime.ts`

**Files:**

- Create: `web/lib/relativeTime.ts`
- Test: `web/lib/__tests__/relativeTime.test.ts`

**Interfaces:**

- Consumes: nothing (pure).
- Produces: `shortRelativeTime(date: Date, now?: Date): string`.

Ports `RelativeTime.short(from:now:)` from `ios/Venn/Utils/RelativeTime.swift` exactly — same thresholds, same terse labels, same injectable `now` for deterministic tests.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/relativeTime.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { shortRelativeTime } from "@/lib/relativeTime";

const now = new Date("2026-08-04T12:00:00.000Z");

function ago(ms: number): Date {
  return new Date(now.getTime() - ms);
}

const SECOND = 1000;
const MINUTE = 60 * SECOND;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const WEEK = 7 * DAY;

describe("shortRelativeTime", () => {
  it("shows 'now' for anything under a minute", () => {
    expect(shortRelativeTime(ago(0), now)).toBe("now");
    expect(shortRelativeTime(ago(59 * SECOND), now)).toBe("now");
  });

  it("shows whole minutes under an hour", () => {
    expect(shortRelativeTime(ago(MINUTE), now)).toBe("1m");
    expect(shortRelativeTime(ago(59 * MINUTE), now)).toBe("59m");
  });

  it("shows whole hours under a day", () => {
    expect(shortRelativeTime(ago(HOUR), now)).toBe("1h");
    expect(shortRelativeTime(ago(23 * HOUR), now)).toBe("23h");
  });

  it("shows whole days under a week", () => {
    expect(shortRelativeTime(ago(DAY), now)).toBe("1d");
    expect(shortRelativeTime(ago(6 * DAY), now)).toBe("6d");
  });

  it("falls back to weeks beyond a week", () => {
    expect(shortRelativeTime(ago(WEEK), now)).toBe("1w");
    expect(shortRelativeTime(ago(9 * WEEK), now)).toBe("9w");
  });

  it("clamps a future date to 'now' rather than showing a negative", () => {
    expect(shortRelativeTime(new Date(now.getTime() + HOUR), now)).toBe("now");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- relativeTime`
Expected: FAIL — `Cannot find module '@/lib/relativeTime'`.

- [ ] **Step 3: Write the implementation**

Create `web/lib/relativeTime.ts`:

```ts
/**
 * Ports RelativeTime.short(from:now:) from ios/Venn/Utils/RelativeTime.swift
 * — same thresholds, same terse labels ("now", "5m", "2h", "3d", "2w"). No
 * "ago" suffix: these sit in a dense feed row and need to stay quiet.
 * `now` is injectable so formatting is deterministic in tests.
 */
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const WEEK = 7 * DAY;

export function shortRelativeTime(date: Date, now: Date = new Date()): string {
  // Clamped: clock skew between the DB and the browser can put a
  // just-created post slightly in the future, and "-1m" looks broken.
  const elapsed = Math.max(0, now.getTime() - date.getTime());

  if (elapsed < MINUTE) return "now";
  if (elapsed < HOUR) return `${Math.floor(elapsed / MINUTE)}m`;
  if (elapsed < DAY) return `${Math.floor(elapsed / HOUR)}h`;
  if (elapsed < WEEK) return `${Math.floor(elapsed / DAY)}d`;
  return `${Math.floor(elapsed / WEEK)}w`;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- relativeTime`
Expected: PASS — 6 tests green.

- [ ] **Step 5: Commit**

```bash
git add web/lib/relativeTime.ts web/lib/__tests__/relativeTime.test.ts
git commit -m "feat(web): add relative-time labels, ported from RelativeTime.swift"
```

---

### Task 3: `lib/feed.ts`

**Files:**

- Create: `web/lib/feed.ts`
- Test: `web/lib/__tests__/feed.test.ts`

**Interfaces:**

- Consumes: `UserProfile`, `ProfileRow`, `toUserProfile` from `@/lib/profile`.
- Produces: `type MediaKind = "movie" | "show" | "book" | "album"`; `type PostAction = "logged" | "rated" | "saved"`; `interface FeedMedia { id, kind, title, year, primaryCreator, coverUrl }`; `interface FeedPost { id, action, rating, caption, createdAt, media, author }`; `toFeedPost(row: FeedPostRow): FeedPost | null`; `feedCursor(date: Date): string`; `fetchFeedPage(client, options?: { limit?: number; before?: Date }): Promise<FeedPost[]>`; `FEED_PAGE_SIZE`.

Ports `FeedService.swift`. iOS's no-session global-feed fallback is deliberately not ported — every web page already requires auth.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/feed.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { feedCursor, toFeedPost, type FeedPostRow } from "@/lib/feed";

const authorRow = {
  id: "11111111-1111-1111-1111-111111111111",
  username: "ada",
  display_name: "Ada",
  avatar_url: null,
  bio: null,
  is_private: false,
  created_at: "2026-01-01T00:00:00Z"
};

function row(overrides: Partial<FeedPostRow> = {}): FeedPostRow {
  return {
    id: "22222222-2222-2222-2222-222222222222",
    author_id: authorRow.id,
    media_id: "33333333-3333-3333-3333-333333333333",
    action: "logged",
    rating: null,
    caption: null,
    created_at: "2026-08-01T10:00:00Z",
    media: {
      id: "33333333-3333-3333-3333-333333333333",
      kind: "movie",
      title: "Past Lives",
      year: 2023,
      primary_creator: "Celine Song",
      cover_url: "https://example.test/cover.jpg"
    },
    author: authorRow,
    ...overrides
  };
}

describe("toFeedPost", () => {
  it("maps a complete row into the domain shape", () => {
    const post = toFeedPost(row({ rating: 4.5, caption: "Devastating." }));

    expect(post).not.toBeNull();
    expect(post?.media.title).toBe("Past Lives");
    expect(post?.media.year).toBe(2023);
    expect(post?.rating).toBe(4.5);
    expect(post?.caption).toBe("Devastating.");
    expect(post?.author.username).toBe("ada");
    expect(post?.createdAt).toBeInstanceOf(Date);
  });

  it("drops a post whose action is not a known value", () => {
    expect(toFeedPost(row({ action: "yodelled" as FeedPostRow["action"] }))).toBeNull();
  });

  it("drops a post whose media kind is not a known value", () => {
    const bad = row();
    bad.media.kind = "hologram" as FeedPostRow["media"]["kind"];
    expect(toFeedPost(bad)).toBeNull();
  });

  it("keeps a post with no rating, caption, year, or cover", () => {
    const sparse = row();
    sparse.media.year = null;
    sparse.media.primary_creator = null;
    sparse.media.cover_url = null;

    const post = toFeedPost(sparse);

    expect(post).not.toBeNull();
    expect(post?.media.year).toBeNull();
    expect(post?.media.coverUrl).toBeNull();
    expect(post?.rating).toBeNull();
  });
});

describe("feedCursor", () => {
  it("keeps fractional seconds", () => {
    // Without milliseconds every post created in the same second as the
    // cursor is skipped on the next page.
    expect(feedCursor(new Date("2026-08-01T10:00:00.123Z"))).toBe("2026-08-01T10:00:00.123Z");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- feed`
Expected: FAIL — `Cannot find module '@/lib/feed'`.

- [ ] **Step 3: Write the implementation**

Create `web/lib/feed.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

/** Mirrors `public.media_kind` / ios/Venn/Models/Media.swift's MediaKind. */
export type MediaKind = "movie" | "show" | "book" | "album";
/** Mirrors `public.post_action` / ios/Venn/Models/Post.swift's PostAction. */
export type PostAction = "logged" | "rated" | "saved";

const MEDIA_KINDS: readonly string[] = ["movie", "show", "book", "album"];
const POST_ACTIONS: readonly string[] = ["logged", "rated", "saved"];

export const FEED_PAGE_SIZE = 20;

export interface FeedMedia {
  id: string;
  kind: MediaKind;
  title: string;
  year: number | null;
  primaryCreator: string | null;
  coverUrl: string | null;
}

export interface FeedPost {
  id: string;
  action: PostAction;
  rating: number | null;
  caption: string | null;
  createdAt: Date;
  media: FeedMedia;
  author: UserProfile;
}

export interface FeedMediaRow {
  id: string;
  kind: MediaKind;
  title: string;
  year: number | null;
  primary_creator: string | null;
  cover_url: string | null;
}

export interface FeedPostRow {
  id: string;
  author_id: string;
  media_id: string;
  action: PostAction;
  rating: number | null;
  caption: string | null;
  created_at: string;
  media: FeedMediaRow;
  author: ProfileRow;
}

/**
 * Lifts a joined wire row into the domain shape. Returns null when `action`
 * or media `kind` holds a value this client doesn't know — mirrors iOS's
 * `compactMap(FeedPost.init(row:))`. That's what keeps an already-deployed
 * client from breaking when a new media kind ships server-side ahead of a
 * client release: unknown items vanish rather than crashing the feed.
 */
export function toFeedPost(row: FeedPostRow): FeedPost | null {
  if (!POST_ACTIONS.includes(row.action)) return null;
  if (!row.media || !MEDIA_KINDS.includes(row.media.kind)) return null;

  return {
    id: row.id,
    action: row.action,
    rating: row.rating,
    caption: row.caption,
    createdAt: new Date(row.created_at),
    media: {
      id: row.media.id,
      kind: row.media.kind,
      title: row.media.title,
      year: row.media.year,
      primaryCreator: row.media.primary_creator,
      coverUrl: row.media.cover_url
    },
    author: toUserProfile(row.author)
  };
}

/**
 * Serializes the keyset cursor. Fractional seconds are load-bearing:
 * without them, every post created in the same second as the cursor is
 * skipped on the following page. Same reasoning as FeedService.cursor(_:).
 */
export function feedCursor(date: Date): string {
  return date.toISOString();
}

/**
 * Recent posts from people the viewer follows, plus their own, newest
 * first. Mirrors `FeedService.recentPosts(limit:before:)`.
 *
 * Pagination is keyset-on-created_at, not offset: an offset silently
 * duplicates rows when new posts land between page fetches.
 *
 * Two round trips (graph, then posts) matches iOS and its known limit —
 * the `in (…)` list bloats the URL past a few hundred follows
 * (docs/TECH_DEBT.md row 5). Fixing that means an RPC serving both clients.
 */
export async function fetchFeedPage(
  client: SupabaseClient,
  options: { limit?: number; before?: Date } = {}
): Promise<FeedPost[]> {
  const limit = options.limit ?? FEED_PAGE_SIZE;

  const {
    data: { user }
  } = await client.auth.getUser();
  if (!user) return [];

  const { data: follows, error: followsError } = await client
    .from("follows")
    .select("followee_id")
    .eq("follower_id", user.id)
    .eq("status", "accepted");
  if (followsError) throw followsError;

  const authorIds = [...(follows ?? []).map((f) => f.followee_id as string), user.id];

  let query = client
    .from("posts")
    .select("*, media(*), author:profiles(*)")
    .in("author_id", authorIds);

  if (options.before) {
    query = query.lt("created_at", feedCursor(options.before));
  }

  const { data, error } = await query.order("created_at", { ascending: false }).limit(limit);
  if (error) throw error;

  return ((data ?? []) as FeedPostRow[])
    .map(toFeedPost)
    .filter((post): post is FeedPost => post !== null);
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- feed`
Expected: PASS — 5 tests green.

- [ ] **Step 5: Commit**

```bash
git add web/lib/feed.ts web/lib/__tests__/feed.test.ts
git commit -m "feat(web): add feed data layer, ported from FeedService.swift"
```

---

### Task 4: `components/Avatar.tsx`

**Files:**

- Create: `web/components/Avatar.tsx`
- Test: `web/components/__tests__/Avatar.test.tsx`

**Interfaces:**

- Consumes: nothing.
- Produces: `<Avatar name={string} avatarUrl={string | null} size?: number />`.

Closes the gap where onboarding uploads a photo that nothing renders. The fallback reproduces the initial-in-a-circle treatment `app/profile/page.tsx` uses today.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/Avatar.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Avatar } from "@/components/Avatar";

describe("Avatar", () => {
  it("renders the image when a URL is present", () => {
    render(<Avatar name="Ada" avatarUrl="https://example.test/a.jpg" />);
    const image = screen.getByRole("img");
    expect(image.getAttribute("src")).toBe("https://example.test/a.jpg");
  });

  it("falls back to the first initial when there is no URL", () => {
    render(<Avatar name="Ada" avatarUrl={null} />);
    expect(screen.getByText("A")).toBeDefined();
    expect(screen.queryByRole("img")).toBeNull();
  });

  it("uppercases a lowercase name's initial", () => {
    render(<Avatar name="ada" avatarUrl={null} />);
    expect(screen.getByText("A")).toBeDefined();
  });

  it("renders a fallback glyph for an empty name rather than an empty circle", () => {
    render(<Avatar name="" avatarUrl={null} />);
    expect(screen.getByText("?")).toBeDefined();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- Avatar`
Expected: FAIL — `Cannot find module '@/components/Avatar'`.

- [ ] **Step 3: Write the implementation**

Create `web/components/Avatar.tsx`:

```tsx
interface AvatarProps {
  /** Display name or username — only its first character is shown in the fallback. */
  name: string;
  avatarUrl: string | null;
  /** Rendered size in px. Matches the 72px both profile headers already use. */
  size?: number;
}

/**
 * Profile image with an initial-in-a-circle fallback, mirroring iOS's
 * AvatarBadge. Plain <img> rather than next/image: avatars and cover art
 * come from four external hosts, and Vercel bills per image
 * transformation (see the Phase 3 spec).
 */
export function Avatar({ name, avatarUrl, size = 72 }: AvatarProps) {
  const initial = name.trim().charAt(0).toUpperCase() || "?";

  return (
    <div
      className="flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-(--color-graphite) font-semibold text-(--color-on-accent)"
      style={{ width: size, height: size, fontSize: Math.round(size / 3) }}
    >
      {avatarUrl ? (
        // eslint-disable-next-line @next/next/no-img-element -- see the component doc comment
        <img
          src={avatarUrl}
          alt=""
          width={size}
          height={size}
          loading="lazy"
          className="h-full w-full object-cover"
        />
      ) : (
        initial
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- Avatar`
Expected: PASS — 4 tests green.

- [ ] **Step 5: Commit**

```bash
git add web/components/Avatar.tsx web/components/__tests__/Avatar.test.tsx
git commit -m "feat(web): add Avatar component with initial fallback"
```

---

### Task 5: `components/FeedRow.tsx`

**Files:**

- Create: `web/components/FeedRow.tsx`
- Test: `web/components/__tests__/FeedRow.test.tsx`

**Interfaces:**

- Consumes: `FeedPost` from `@/lib/feed`; `shortRelativeTime` from `@/lib/relativeTime`; `Avatar` from `@/components/Avatar`.
- Produces: `<FeedRow post={FeedPost} />`.

Ports `FeedRow.swift`: attribution line, cover, title with metadata, optional rating, optional caption. iOS's metadata line joins year and creator with " · " and omits whichever is missing.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/FeedRow.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { FeedRow } from "@/components/FeedRow";
import type { FeedPost } from "@/lib/feed";

function post(overrides: Partial<FeedPost> = {}): FeedPost {
  return {
    id: "p1",
    action: "logged",
    rating: null,
    caption: null,
    createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
    media: {
      id: "m1",
      kind: "movie",
      title: "Past Lives",
      year: 2023,
      primaryCreator: "Celine Song",
      coverUrl: "https://example.test/cover.jpg"
    },
    author: {
      id: "u1",
      username: "ada",
      displayName: "Ada",
      avatarUrl: null,
      bio: null,
      isPrivate: false,
      createdAt: "2026-01-01T00:00:00Z"
    },
    ...overrides
  };
}

describe("FeedRow", () => {
  it("shows who did what, and when", () => {
    render(<FeedRow post={post()} />);
    expect(screen.getByText("Ada logged")).toBeDefined();
    expect(screen.getByText("2h")).toBeDefined();
  });

  it("falls back to the username when there is no display name", () => {
    render(<FeedRow post={post({ author: { ...post().author, displayName: null } })} />);
    expect(screen.getByText("ada logged")).toBeDefined();
  });

  it("joins year and creator for the metadata line", () => {
    render(<FeedRow post={post()} />);
    expect(screen.getByText("2023 · Celine Song")).toBeDefined();
  });

  it("omits the separator when only the year is known", () => {
    const sparse = post();
    sparse.media.primaryCreator = null;
    render(<FeedRow post={sparse} />);
    expect(screen.getByText("2023")).toBeDefined();
  });

  it("shows the rating only when there is one", () => {
    const { unmount } = render(<FeedRow post={post({ rating: 4.5 })} />);
    expect(screen.getByText("4.5")).toBeDefined();
    unmount();

    render(<FeedRow post={post()} />);
    expect(screen.queryByText("4.5")).toBeNull();
  });

  it("shows the caption only when there is one", () => {
    render(<FeedRow post={post({ caption: "Devastating." })} />);
    expect(screen.getByText("Devastating.")).toBeDefined();
  });

  it("links the author to their profile", () => {
    render(<FeedRow post={post()} />);
    expect(screen.getByRole("link", { name: /Ada/ }).getAttribute("href")).toBe("/ada");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- FeedRow`
Expected: FAIL — `Cannot find module '@/components/FeedRow'`.

- [ ] **Step 3: Write the implementation**

Create `web/components/FeedRow.tsx`:

```tsx
import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import type { FeedPost } from "@/lib/feed";
import { shortRelativeTime } from "@/lib/relativeTime";

interface FeedRowProps {
  post: FeedPost;
}

/**
 * One feed entry, porting ios/Venn/Features/Feed/FeedRow.swift: attribution,
 * a large cover, title and metadata, an optional rating, an optional note.
 */
export function FeedRow({ post }: FeedRowProps) {
  const authorName = post.author.displayName ?? post.author.username;
  // "2023 · Celine Song" — whichever of year / creator is present.
  const metadata = [post.media.year?.toString(), post.media.primaryCreator]
    .filter((part): part is string => Boolean(part))
    .join(" · ");

  return (
    <article className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <Link href={`/${post.author.username}`} className="flex items-center gap-2">
          <Avatar name={authorName} avatarUrl={post.author.avatarUrl} size={28} />
          <span className="text-sm font-medium text-(--color-text-secondary)">
            {authorName} {post.action}
          </span>
        </Link>
        <span className="ml-auto text-xs text-(--color-text-secondary)">
          {shortRelativeTime(post.createdAt)}
        </span>
      </div>

      <div className="flex h-[200px] items-center justify-center overflow-hidden rounded-md bg-(--color-surface-strong)">
        {post.media.coverUrl ? (
          // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
          <img
            src={post.media.coverUrl}
            alt=""
            loading="lazy"
            className="h-full w-full object-cover"
          />
        ) : (
          <span className="px-4 text-center text-(--color-text-secondary)">{post.media.title}</span>
        )}
      </div>

      <div className="flex items-baseline gap-3">
        <div className="flex flex-col gap-0.5">
          <h2 className="text-lg font-semibold text-(--color-text-primary)">{post.media.title}</h2>
          {metadata && <p className="text-sm text-(--color-text-secondary)">{metadata}</p>}
        </div>
        {post.rating !== null && (
          <span className="ml-auto shrink-0 text-sm font-semibold text-(--color-text-primary)">
            <span className="text-(--color-accent)">★</span> {post.rating.toFixed(1)}
          </span>
        )}
      </div>

      {post.caption && <p className="text-(--color-text-secondary)">{post.caption}</p>}
    </article>
  );
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- FeedRow`
Expected: PASS — 7 tests green.

- [ ] **Step 5: Commit**

```bash
git add web/components/FeedRow.tsx web/components/__tests__/FeedRow.test.tsx
git commit -m "feat(web): add FeedRow, ported from FeedRow.swift"
```

---

### Task 6: `components/AppNav.tsx` + route groups

**Files:**

- Create: `web/components/AppNav.tsx`
- Create: `web/app/(app)/layout.tsx`
- Move: `web/app/profile/` → `web/app/(app)/profile/`
- Move: `web/app/requests/` → `web/app/(app)/requests/`
- Move: `web/app/[username]/` → `web/app/(app)/[username]/`
- Move: `web/app/login/` → `web/app/(auth)/login/`
- Move: `web/app/onboarding/` → `web/app/(auth)/onboarding/`
- Test: `web/components/__tests__/AppNav.test.tsx`

**Interfaces:**

- Consumes: nothing.
- Produces: `<AppNav />`.

Route groups do not change URLs — `/profile` stays `/profile`. Use `git mv` so history follows the files.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/AppNav.test.tsx`:

```tsx
import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AppNav } from "@/components/AppNav";

vi.mock("next/navigation", () => ({
  usePathname: () => "/feed"
}));

describe("AppNav", () => {
  it("links to the feed and the profile", () => {
    render(<AppNav />);
    expect(screen.getByRole("link", { name: "Feed" }).getAttribute("href")).toBe("/feed");
    expect(screen.getByRole("link", { name: "Profile" }).getAttribute("href")).toBe("/profile");
  });

  it("shows Explorer as disabled rather than as a dead link", () => {
    render(<AppNav />);
    expect(screen.queryByRole("link", { name: /Explorer/ })).toBeNull();
    const explorer = screen.getByText("Explorer");
    expect(explorer.getAttribute("aria-disabled")).toBe("true");
  });

  it("marks the active route for assistive tech", () => {
    render(<AppNav />);
    expect(screen.getByRole("link", { name: "Feed" }).getAttribute("aria-current")).toBe("page");
    expect(screen.getByRole("link", { name: "Profile" }).getAttribute("aria-current")).toBeNull();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- AppNav`
Expected: FAIL — `Cannot find module '@/components/AppNav'`.

- [ ] **Step 3: Write the component**

Create `web/components/AppNav.tsx`:

```tsx
"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

/**
 * Persistent nav for authenticated pages, mirroring iOS's tab bar
 * (Feed / Explorer / Profile). Explorer is rendered disabled until that
 * phase ships — showing the final shape without offering a dead link.
 * Follow requests stay off the nav and are reached from the profile page,
 * matching where iOS puts them (ProfileView's top bar, private accounts).
 */
const TABS = [
  { href: "/feed", label: "Feed" },
  { href: "/profile", label: "Profile" }
] as const;

export function AppNav() {
  const pathname = usePathname();

  return (
    <nav className="sticky top-0 z-10 border-b border-(--color-separator) bg-(--color-background)">
      <ul className="mx-auto flex max-w-lg items-center gap-6 px-4 py-3">
        <li className="mr-auto font-semibold text-(--color-text-primary)">venn</li>
        {TABS.map((tab) => {
          const active = pathname === tab.href;
          return (
            <li key={tab.href}>
              <Link
                href={tab.href}
                aria-current={active ? "page" : undefined}
                className={
                  active
                    ? "font-semibold text-(--color-accent)"
                    : "text-(--color-text-secondary) hover:text-(--color-text-primary)"
                }
              >
                {tab.label}
              </Link>
            </li>
          );
        })}
        <li>
          <span aria-disabled="true" title="Coming soon" className="text-(--color-separator)">
            Explorer
          </span>
        </li>
      </ul>
    </nav>
  );
}
```

- [ ] **Step 4: Move the routes into groups**

```bash
cd web/app
mkdir -p "(app)" "(auth)"
git mv profile "(app)/profile"
git mv requests "(app)/requests"
git mv "[username]" "(app)/[username]"
git mv login "(auth)/login"
git mv onboarding "(auth)/onboarding"
```

- [ ] **Step 5: Add the authenticated layout**

Create `web/app/(app)/layout.tsx`:

```tsx
import { AppNav } from "@/components/AppNav";

/**
 * Shell for signed-in pages. Pages under (auth) — login, onboarding —
 * deliberately get no nav: there's nothing useful to navigate to before
 * you have a profile. Route groups don't affect URLs.
 */
export default function AppLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <AppNav />
      {children}
    </>
  );
}
```

- [ ] **Step 6: Verify the tests and the build**

Run: `cd web && npm run test && npm run build`
Expected: tests PASS; build succeeds and still lists `/profile`, `/requests`, `/[username]`, `/login`, `/onboarding` as routes.

- [ ] **Step 7: Commit**

```bash
git add -A web/app web/components/AppNav.tsx web/components/__tests__/AppNav.test.tsx
git commit -m "feat(web): add navigation shell and split routes into app/auth groups"
```

---

### Task 7: `app/(app)/feed/page.tsx` + `components/FeedPagination.tsx`

**Files:**

- Create: `web/app/(app)/feed/page.tsx`
- Create: `web/components/FeedPagination.tsx`
- Modify: `web/app/page.tsx` (redirect signed-in users to `/feed`)
- Test: `web/e2e/feed.spec.ts`

**Interfaces:**

- Consumes: `fetchFeedPage`, `FEED_PAGE_SIZE`, `FeedPost` from `@/lib/feed`; `FeedRow`.
- Produces: the `/feed` route.

**Empty-state copy (approved deviation from iOS):** title "Quiet for now", message "Your feed shows people you follow." iOS's second sentence points at the Explorer tab and the composer, neither of which exists on web yet; it is restored when they ship.

- [ ] **Step 1: Write the pagination component**

Create `web/components/FeedPagination.tsx`:

```tsx
"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { FeedRow } from "@/components/FeedRow";
import { FEED_PAGE_SIZE, fetchFeedPage, type FeedPost } from "@/lib/feed";
import { createClient } from "@/lib/supabase/client";

interface FeedPaginationProps {
  /** Cursor from the last server-rendered post — where page 2 starts. */
  initialCursor: string;
  /** False when the server's first page came back short (feed exhausted). */
  initialHasMore: boolean;
}

/**
 * Owns pages 2..n. The first page is server-rendered by the feed page;
 * this takes over once the sentinel scrolls into view — the web equivalent
 * of iOS's lazy footer `.task` trigger in FeedView.
 */
export function FeedPagination({ initialCursor, initialHasMore }: FeedPaginationProps) {
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [cursor, setCursor] = useState(initialCursor);
  const [hasMore, setHasMore] = useState(initialHasMore);
  const [failed, setFailed] = useState(false);
  const loadingRef = useRef(false);
  const sentinelRef = useRef<HTMLDivElement>(null);

  const loadMore = useCallback(async () => {
    // A ref, not state: the observer can fire again before a state update
    // has rendered, which would fetch the same page twice.
    if (loadingRef.current || !hasMore) return;
    loadingRef.current = true;
    setFailed(false);

    try {
      const next = await fetchFeedPage(createClient(), {
        before: new Date(cursor),
        limit: FEED_PAGE_SIZE
      });

      // Short page means the feed is exhausted. Note this counts rows
      // returned by the query, not rows kept after dropping unknown
      // kinds, so a page that is short only because of drops still ends
      // pagination — acceptable, and it matches iOS's hasMore.
      if (next.length < FEED_PAGE_SIZE) setHasMore(false);
      if (next.length > 0) {
        setPosts((current) => [...current, ...next]);
        setCursor(next[next.length - 1].createdAt.toISOString());
      }
    } catch {
      setFailed(true);
    } finally {
      loadingRef.current = false;
    }
  }, [cursor, hasMore]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || !hasMore) return;

    const observer = new IntersectionObserver((entries) => {
      if (entries[0]?.isIntersecting) void loadMore();
    });
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [loadMore, hasMore]);

  return (
    <>
      {posts.map((post) => (
        <FeedRow key={post.id} post={post} />
      ))}

      {failed && (
        <button
          type="button"
          onClick={() => void loadMore()}
          className="self-center text-sm font-semibold text-(--color-accent)"
        >
          Couldn&apos;t load more. Try again
        </button>
      )}

      {hasMore && !failed && <div ref={sentinelRef} className="h-8" aria-hidden="true" />}
    </>
  );
}
```

- [ ] **Step 2: Write the feed page**

Create `web/app/(app)/feed/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { FeedPagination } from "@/components/FeedPagination";
import { FeedRow } from "@/components/FeedRow";
import { FEED_PAGE_SIZE, fetchFeedPage } from "@/lib/feed";
import { createClient } from "@/lib/supabase/server";

export default async function FeedPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  let posts;
  try {
    posts = await fetchFeedPage(supabase, { limit: FEED_PAGE_SIZE });
  } catch {
    return (
      <main className="mx-auto flex max-w-lg flex-col gap-4 px-4 py-8">
        <p className="text-(--color-text-secondary)">Couldn&apos;t load the feed.</p>
      </main>
    );
  }

  if (posts.length === 0) {
    return (
      <main className="mx-auto flex max-w-lg flex-col gap-2 px-4 py-16 text-center">
        <h1 className="text-lg font-semibold text-(--color-text-primary)">Quiet for now</h1>
        <p className="text-(--color-text-secondary)">Your feed shows people you follow.</p>
      </main>
    );
  }

  const lastPost = posts[posts.length - 1];

  return (
    <main className="mx-auto flex max-w-lg flex-col gap-10 px-4 py-8">
      {posts.map((post) => (
        <FeedRow key={post.id} post={post} />
      ))}
      <FeedPagination
        initialCursor={lastPost.createdAt.toISOString()}
        initialHasMore={posts.length >= FEED_PAGE_SIZE}
      />
    </main>
  );
}
```

- [ ] **Step 3: Point the root route at the feed**

In `web/app/page.tsx`, change the redirect target:

```tsx
redirect(user ? "/feed" : "/login");
```

- [ ] **Step 4: Write the E2E test**

Create `web/e2e/feed.spec.ts`:

```ts
import { expect, test } from "@playwright/test";

// Signed-out coverage only: the suite still has no authenticated-session
// fixture (docs/TECH_DEBT.md row 13), so the feed's rendered content is
// covered by component tests instead.
test.describe("feed auth gate", () => {
  test("visiting /feed while signed out redirects to /login", async ({ page }) => {
    await page.goto("/feed");
    await expect(page).toHaveURL(/\/login/);
  });

  test("the nav is not shown on the sign-in page", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("link", { name: "Feed" })).toHaveCount(0);
  });
});
```

- [ ] **Step 5: Verify everything**

Run: `cd web && npm run lint && npm run test && npm run build && npm run test:e2e`
Expected: all pass; the build lists `/feed` among the routes.

- [ ] **Step 6: Commit**

```bash
git add web/app web/components/FeedPagination.tsx web/e2e/feed.spec.ts
git commit -m "feat(web): add the feed page with cursor-based infinite scroll"
```

---

### Task 8: Adopt `Avatar` on the profile pages + log the tech debt

**Files:**

- Modify: `web/app/(app)/profile/page.tsx`
- Modify: `web/app/(app)/[username]/page.tsx`
- Modify: `docs/TECH_DEBT.md`

**Interfaces:**

- Consumes: `Avatar` from `@/components/Avatar`.
- Produces: nothing new.

- [ ] **Step 1: Replace both hand-rolled avatar circles**

In each page, delete the `initial` local and the `<div className="flex h-[72px] w-[72px] …">{initial}</div>` block, and render instead:

```tsx
<Avatar name={profile.displayName ?? profile.username} avatarUrl={profile.avatarUrl} />
```

Add `import { Avatar } from "@/components/Avatar";` to both files.

- [ ] **Step 2: Log the new-user dead end**

Append a row to the table in `docs/TECH_DEBT.md`:

```markdown
| 16 | A brand-new web user who follows nobody sees the empty feed with no in-app way to find anyone — people search is a later phase, so there is no path from "empty feed" to "following someone" on web. | Phase ordering: the feed ships before Explorer, and iOS's empty-state copy points at an Explorer tab web doesn't have yet. | Ships with Explorer / people search. At that point restore iOS's full empty-state sentence ("Find them under People in the Explorer tab — or log something yourself.") so rule 17 copy parity holds exactly. |
```

- [ ] **Step 3: Verify**

Run: `cd web && npm run lint && npm run test && npm run build`
Expected: all pass.

- [ ] **Step 4: Format the docs with the pinned prettier**

Run from the repo root:

```bash
npx --yes prettier@3.9.6 --write docs/TECH_DEBT.md
```

- [ ] **Step 5: Commit**

```bash
git add web/app docs/TECH_DEBT.md
git commit -m "feat(web): render avatars on both profile pages"
```

---

## Self-Review

**Spec coverage.** Feed → Tasks 3, 5, 7. Navigation shell → Task 6. Avatars → Tasks 4, 8. Reserved usernames → Task 1. Relative time → Task 2. Empty/error states → Task 7. Testing → every task. Tech-debt logging → Task 8.

**Known gaps, deliberate.** Playwright still cannot cover signed-in feed rendering (tech-debt row 13); component tests carry that load. `fetchFeedPage`'s network path is not unit-tested — only its pure helpers are — matching how `lib/follow.ts` and `lib/overlap.ts` were tested in Phase 2.

**Type consistency.** `FeedPost`, `FeedMedia`, `FeedPostRow`, `MediaKind`, `PostAction`, `toFeedPost`, `feedCursor`, `fetchFeedPage`, `FEED_PAGE_SIZE` are defined in Task 3 and used with identical names and shapes in Tasks 5 and 7. `Avatar`'s props (`name`, `avatarUrl`, `size`) match across Tasks 4, 5, and 8.
