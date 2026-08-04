# venn web app — Phase 4: the composer

## Context

Phase 3 gave web the feed, navigation, avatars, profile shelves, editing, settings, and follow lists. Web now lacks exactly three iOS surfaces: the composer, Explorer/people search, and Year in Review.

The composer comes first, and not only because of roadmap order. The production database currently holds **zero posts**, which is why the feed that just shipped renders "Quiet for now" for everyone. Until a web user can log something, the feed has nothing to show and the empty-state dead end (tech-debt row 16) stays open. This is the product's core loop — "log what you consume" — and web cannot do it at all.

## Scope

- **`/composer`**: search a media catalog, pick a result, then either save it to the watchlist or rate it, caption it, and log it. Ports `ios/Venn/Features/Composer/`.
- **`/api/catalog/search`**: a server-side Route Handler that holds the TMDB key and normalizes results from all three providers.
- **A "Log" entry point** in `AppNav`.
- **A post rate-limit migration** benefiting both platforms.

### Explicitly out of scope

Explorer and people search (a later phase — this composer is reached from the nav, not from a search result the way iOS does it), Year in Review, editing or deleting a post after creation, and pagination of search results (page 1 only, matching what the iOS composer surfaces in practice).

## Architecture

### Why the catalog calls run server-side

iOS ships the TMDB key inside the app binary, which the team accepted on the documented reasoning that anything in a binary is effectively public. Web has a real server, so it does not have to make that trade.

`TMDB_API_KEY` is a **server-only** environment variable — deliberately no `NEXT_PUBLIC_` prefix, so Next.js never inlines it into the client bundle. Only the Route Handler reads it.

Two further reasons the keyless providers also go through the server rather than being called from the browser:

- **MusicBrainz requires a meaningful `User-Agent`** identifying the application, and enforces strict per-IP limits. A browser cannot set a custom UA, so browser-direct calls would be both a poor citizen and rate-limited against the user's own IP.
- One endpoint means one normalization boundary, one error shape, and one place to rate-limit. Proxying only TMDB would leave two code paths that drift.

### Routing

- `app/(app)/composer/page.tsx` — auth-gated Server Component that renders the client composer. `composer` is already in `profiles_username_not_reserved` (applied 2026-08-04), so this needs no migration.
- `app/api/catalog/search/route.ts` — `GET ?kind=<movie|show|book|album>&q=<query>`. Requires a session: an unauthenticated open proxy to the TMDB quota is precisely the risk being avoided. Returns `{ candidates: MediaCandidate[] }`, or `{ error }` with a 4xx/5xx status.

### Catalog layer

`lib/catalog/` mirrors `ios/Venn/Services/Catalog/`, one file per provider so each API's quirks stay isolated:

- `tmdb.ts` — movies and shows; poster URLs built from the `w500` base, same as `TMDBService.posterBase`.
- `openLibrary.ts` — books; cover from the cover id, first author only as `primaryCreator`, `/works/` prefix stripped from the key.
- `musicBrainz.ts` — albums; cover from the Cover Art Archive front image, first artist credit as `primaryCreator`.
- `types.ts` — the shared `MediaCandidate` shape, mirroring `ios/Venn/Models/MediaCandidate.swift`.

Each provider module exports a pure `toCandidates(json)` normalizer alongside its fetch function, so the mapping — where these three APIs differ most — is unit-testable without network access.

### Composer UI

`components/Composer.tsx`, a client component owning a three-state machine that mirrors `ComposerViewModel`:

1. **Searching** — a kind selector (Movies / Shows / Books / Albums) and a query field debounced at 350ms, the same interval as the onboarding username check.
2. **Picked** — the chosen candidate, with two paths: "Add to watchlist" writes immediately, or Love / Like / Dislike (or skip) plus an optional caption.
3. **Submitting** — the button disables and the result is reported.

Sub-components (`CandidateList`, `RatingChips`) live alongside it rather than as private helpers inside one file, per CLAUDE.md rule 16's spirit.

### Write path

`lib/compose.ts`, porting `ComposerService.log(...)`:

- `upsertMedia(client, candidate)` — select-then-insert on `(external_source, external_id)`. PostgREST cannot target the partial unique index `media_external_unique` directly, so a concurrent duplicate insert is caught by the DB constraint and treated as success, exactly as iOS does.
- `createPost(client, { mediaId, action, rating, caption })` — inserts the post row under RLS (`posts_insert_own`).

Rating maps exactly as iOS does: Love → `rated` 5.0, Like → `rated` 3.0, Dislike → `rated` 1.0, skip → `logged` with a null rating, watchlist → `saved` with no rating or caption.

Captions pass through a new `sanitizeCaption` in `lib/sanitize.ts` — 1–500 characters after normalization, mirroring `Sanitize.caption` and the `posts_caption_length` constraint. It is the last validator from `Sanitize.swift` that web lacks.

### Rate limiting

Two limits, at two different boundaries.

**The search endpoint** is limited to **60 searches per minute per user** — matching `request_follow`'s existing budget, and generous against a 350ms debounce (which caps a typing user near 20/min) while stopping a scripted loop from draining the TMDB quota.

It enforces this by calling the existing `public.rl_check` RPC through the caller's own Supabase session, keyed `catalog_search:<user id>`. That is deliberate rather than an in-process counter: Route Handlers run serverless, so an in-memory map resets on every cold start and is not shared between concurrent instances — it would enforce nothing under real traffic. Postgres is the only state all instances share, and `rl_check` is already the project's sliding-window primitive.

**Post creation** is rate-limited by a new `BEFORE INSERT` trigger on `public.posts` calling the existing `public.rl_check` at **30 inserts per minute per author** — far above any human logging session, low enough to stop a runaway script.

A trigger rather than a new RPC, deliberately: it covers **every** insert path, so iOS gets the protection immediately without an iOS release, and any future client is covered by construction. An RPC would only protect callers who remember to use it, and iOS inserts directly today. The trigger raises `P0429`, which `AppError.from(_:)` already maps to `AppError.rateLimited` on iOS, so iOS surfaces it correctly with no Swift change.

Today `posts_insert_own` proves _ownership_ but says nothing about _frequency_ — nothing stops a script inserting thousands of rows. This closes that on both platforms at once.

## Error handling

Continues the established pattern: a loading/loaded/error shape, with errors mapped to user-facing copy at one boundary.

- A missing `TMDB_API_KEY` returns a clear message rather than a generic failure, mirroring iOS's `AppError.validation("Movie search requires a TMDB API key…")`.
- A `P0429` from the post trigger surfaces as "You're logging very fast — give it a moment.", distinct from a generic failure so the user knows waiting will help.
- A search returning nothing renders an empty state, not an error.

## Testing

- **Unit (Vitest)**: each provider's `toCandidates` normalizer, including the sparse cases (no cover, no author, no year) that these APIs return constantly; the rating-to-action mapping; `sanitizeCaption`'s bounds.
- **Component (RTL)**: the composer's state transitions — search results render, picking reveals the rating step, skip versus a rating produces the right action — with the search call mocked.
- **E2E (Playwright)**: `/composer` redirects to `/login` when signed out.

The Route Handler's network path is not tested end to end, matching how `fetchFeedPage` and the other `lib/` fetchers are covered by their pure helpers. The authenticated-session fixture gap (tech-debt row 13) still applies.

## Deployment note

`TMDB_API_KEY` must be set wherever web runs. It is in `web/.env.local` for local development. It is **not** needed by CI — the E2E tests never call the real endpoint, and the key is read per request rather than at build time — but it will be required as an environment variable when web is first deployed, alongside the Supabase values.

## Open questions (not blocking)

- Search results are page 1 only. Infinite scroll on search can follow if the first 20 results prove insufficient in practice; iOS has the paging parameter but its composer does not surface it either.
- Restaurants and games appear in the product vision but exist in neither platform's `media_kind` enum. Out of scope here; they need a schema change and a catalog source first.
