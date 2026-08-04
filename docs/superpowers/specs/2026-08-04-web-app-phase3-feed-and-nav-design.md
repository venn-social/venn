# venn web app — Phase 3: feed + navigation shell

## Context

Phases 1 and 2 gave the web app auth, a read-only own profile, public profiles, the follow lifecycle, and the Venn overlap. Onboarding (PR #139) closed the last blocker to web-first signup. This spec covers Phase 3 from the Phase 1 roadmap: the feed.

Exploring the current web app before writing this surfaced two gaps that were assumed done but never built, and both belong in this phase:

- **There is no navigation.** No `<nav>`, no `<header>`, not one `<Link>` anywhere under `web/app/`. Every page is reachable only by typing its URL. The Phase 1 spec promised "a minimal nav/header shell to hang later phases off of"; it was never implemented. A feed nobody can navigate to is not a shipped feature.
- **Avatars are never rendered.** `lib/profile.ts` fetches `avatarUrl`, and onboarding now uploads one to the `avatars` bucket, but no page displays it — both profile pages show a letter in a grey circle. We currently ask new users for a photo and then never show it to them.

Shelves (Collection/Watchlist), profile editing, and settings were initially cut from this phase to keep it to one coherent story. They were folded back in mid-session once the original scope finished early — see "Scope extension" below.

## Scope

- **Feed** at `/feed`: posts from people the viewer follows plus their own, newest first, infinite-scrolling. Mirrors `ios/Venn/Features/Feed/`.
- **Navigation shell**: a persistent nav on authenticated pages, mirroring iOS's tab bar (Feed / Explorer / Profile).
- **Avatars**: a shared `Avatar` component used in feed rows and both profile pages.
- **Reserved usernames**: a migration extending `profiles_username_not_reserved` to cover the new route and the routes we already know are coming.

### Scope extension (2026-08-04, mid-execution)

Phase 3's tasks finished with time left in the session, so the work originally deferred to "Phase 4" was folded into the same branch and PR at the founder's direction. That added:

- **Profile shelves** — Collection and Watchlist on both `/profile` and `/[username]`. The Phase 2 spec listed these in scope but they were never built. Ports `ProfileShelf.swift`, `ShelfTabs.swift`, and `ProfileShelfGallery.swift`, including the different empty-state copy iOS uses for your own profile ("Nothing in your collection yet.") versus someone else's ("Nothing logged yet."). On a private profile the shelves are gated server-side, so a non-follower's browser never receives them.
- **Profile editing** — `/profile/edit`, porting `ProfileEditView.swift` with the same 160-character bio limit and counter.
- **Account settings** — `/settings`, porting `SettingsView.swift`'s private-account toggle and its explanatory copy.

Media decoding moved into `lib/media.ts` as part of this, so the feed and the shelves share one decoder. On iOS the equivalent pair are near-duplicates tracked as tech-debt row 3 ("if a third copy appears, extract a shared row DTO"); web extracted it before the second copy landed.

### Still out of scope

Composer (logging/rating/saving), Explorer and people search, and Year in Review — each a later phase. Avatar _editing_ is also still absent: onboarding can set a photo, and every surface now displays one, but there is no way to change it after onboarding.

## Architecture

### Routing

Pages are regrouped so navigation can live in a layout rather than being repeated per page. Next.js route groups do not affect URLs, so every existing path, link, and reserved username stays valid:

```
app/
  (auth)/            no nav — a signed-out or profile-less user gets no app chrome
    login/
    onboarding/
  (app)/             layout.tsx renders <AppNav>
    feed/            the feed  (/feed)
    profile/
    requests/
    [username]/
  auth/callback/     route handler, unaffected by either layout
  page.tsx           redirects: /feed when signed in, /login when not
```

`/` continues to redirect rather than hosting the feed itself. The feed lives at its own addressable URL so it can be linked and bookmarked directly.

### Reserved usernames

Public profiles are served from the top-level `/[username]`, so any new static top-level route permanently shadows that username. `/feed` therefore requires extending the `profiles_username_not_reserved` CHECK constraint.

This migration reserves a forward-looking set in one pass — `feed`, `explorer`, `search`, `settings`, `composer`, `notifications`, `about`, `terms`, `privacy` — rather than one migration per route as phases land. Verified against the live database on 2026-08-04: no existing profile holds any of these names, so adding the constraint cannot fail on existing rows. `RESERVED_USERNAMES` in `lib/onboarding.ts` is updated to the same list, and the two must be changed together.

### Data layer

`lib/feed.ts` mirrors `FeedService.swift`:

- `fetchFeedPage(client, { limit, before })` — reads the viewer's follow graph, then posts from those authors plus the viewer, joined with `media` and `author` in a single embedded select, ordered by `created_at` descending.
- Pagination is keyset-on-`created_at` via a `before` cursor, not an offset. An offset silently duplicates rows when new posts land between page fetches; keyset does not, and it rides the existing `posts_created_at_idx`.
- The cursor is serialized with fractional seconds. Without them, every post created in the same second as the cursor is skipped — the same trap `FeedService.cursor(_:)` documents.
- `toFeedPost(row)` returns `null` for a post whose `action` or media `kind` is an unrecognized value, mirroring iOS's `compactMap`. This is what keeps a deployed client from breaking when a new media kind ships server-side ahead of a release.

iOS's fallback to a global feed when there is no session is **not** ported. It exists for previews and the DEBUG design boot; on web every page already requires auth, so a viewer is always present.

The two-round-trip shape (graph, then posts) is kept deliberately, matching iOS and its known limit — tech-debt row 5 already tracks that the `in (…)` list bloats the URL past a few hundred follows. Web adopting the same shape means one fix later, in an RPC, serves both platforms.

### Components

- `components/FeedRow.tsx` — ports `FeedRow.swift`: attribution ("Maya logged", relative time), cover image, title with year and creator, optional rating, optional caption.
- `components/FeedPagination.tsx` — client component holding pages 2..n in state, with an IntersectionObserver on a footer sentinel. This is the direct equivalent of iOS's lazy footer `.task`: the trigger fires because the sentinel scrolled into view.
- `components/Avatar.tsx` — renders `avatarUrl` when present, falls back to the initial-in-a-circle treatment both profile pages use today. Adopted by the feed rows and both profile pages.
- `components/AppNav.tsx` — Feed / Explorer / Profile, mirroring iOS's tab bar. Explorer renders as a disabled control until that phase lands, so the nav's final shape is visible without offering a dead link. Requests stays off the nav and remains reachable from the profile page, matching how iOS puts it in `ProfileView`'s top bar rather than the tab bar.
- `lib/relativeTime.ts` — ports `RelativeTime.swift` ("now", "5m", "2h", "3d", "2w").

### Images

Cover art comes from TMDB, OpenLibrary, and Cover Art Archive; avatars from Supabase storage. Plain `<img>` with `loading="lazy"` and explicit `width`/`height`, not `next/image`.

`next/image` would require allowlisting four external hosts in `next.config.ts`, and on Vercel every transformation is billed — a scrolling feed of cover art is precisely the workload that runs that bill up. The images arrive already appropriately sized from the catalog APIs. Explicit dimensions prevent the layout shift that is the main reason to reach for `next/image` anyway. Revisit if that stops being true.

## Error handling

Continues the established pattern: a loading / loaded / error shape per data-fetching surface, with Supabase errors mapped to user-facing copy at one boundary.

The empty state keeps iOS's title, "Quiet for now", and the first sentence of its message, "Your feed shows people you follow." It drops iOS's second sentence — "Find them under People in the Explorer tab — or log something yourself." — because neither the Explorer tab nor the composer exists on web yet, and copy that points at absent features is worse than shorter copy. The full sentence is restored once Explorer and the composer ship, at which point rule 17's copy parity holds exactly.

This leaves a real dead end: a new web user who follows nobody sees an empty feed and has no in-app way to find anyone, because people-search is a later phase. That is a known consequence of the phase ordering, not an oversight, and is logged in `docs/TECH_DEBT.md` so it is visible rather than implicit.

## Testing

- **Unit (Vitest)**: `relativeTime` boundaries; `toFeedPost`'s unknown-enum drop; cursor serialization including the fractional-seconds case.
- **Component (RTL)**: `FeedRow` rendering (rating present/absent, caption present/absent); `Avatar`'s URL and fallback branches.
- **E2E (Playwright)**: the signed-out redirect from `/feed` to `/login`, and that the nav renders on authenticated routes but not on `/login` or `/onboarding`.

E2E coverage of the feed's actual content remains blocked on tech-debt row 13 — the suite still has no authenticated-session fixture, so signed-in behavior is covered at the component level rather than end to end. This phase does not fix that; it should be stated plainly rather than papered over.

## Open questions (not blocking)

- Whether the feed should poll or use Supabase Realtime for new posts. iOS does neither today — it refreshes on pull. Web matches that (a refresh reloads the Server Component) and Realtime can be revisited when there is enough activity for it to matter.
