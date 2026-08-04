# venn web app — Phase 5: Explorer

## Context

Phase 4 gave web the composer, so a user can finally create a post. Web now lacks two iOS surfaces: Explorer and Year in Review.

Explorer matters more than its roadmap position suggests. A web user can now log things and fill their own feed, but there is still **no way on web to find another person**. Following people is what makes the Venn overlap — the product's whole premise — mean anything. This is the unresolved half of tech-debt row 16.

## Scope

- **`/explorer`** with the six categories iOS has: All, People, Movies, TV, Music, Books.
- **People search** over `profiles`, with the same injection-safe pattern building iOS uses.
- **Media search** for the four media categories, reusing the composer's existing `/api/catalog/search`.
- **Catalog browse** — recent media of a kind — for the four media categories.
- **`sanitizeSearchQuery`** in `lib/sanitize.ts`, the last validator from `Sanitize.swift` web lacks.
- **Composer prefill**: `/composer?kind=&q=` so an Explorer media result can start a log.

### Explicitly out of scope

Year in Review. Ranked or personalized recommendations — see the honesty note below. Pagination of search results (limit 20, matching iOS).

## The security-critical part

`PeopleSearchService` builds a **raw PostgREST filter string**:

```
username.ilike.*term*,display_name.ilike.*term*
```

PostgREST parses that string itself. Inside it, commas separate conditions, dots separate column/operator/value, parens group, quotes delimit — all syntax. `*` and `%` are multi-character wildcards. Interpolating untrusted input directly would let a user corrupt the filter or widen the match arbitrarily.

`containsPattern` therefore strips everything except letters (including accented ones), digits, spaces, `_`, and `-`, collapses whitespace, and returns `""` when nothing searchable survives — the caller then returns no results rather than issuing a query. `_` is deliberately kept despite being a single-character LIKE wildcard: it is part of the username alphabet, and it still matches itself, so the worst case is a benign over-match.

Web ports this exactly, as `containsPattern` in `lib/people.ts`, with the same character policy and the same empty-string guard. This is the one piece of this phase where a mistake is a security bug rather than a cosmetic one, so it gets direct unit tests for the characters that matter.

Separately, `sanitizeSearchQuery` (normalise + 100-char cap) mirrors `Sanitize.searchQuery` and runs before the pattern is built, per CLAUDE.md rule 7.

## Architecture

### Routing

`app/(app)/explorer/page.tsx` — auth-gated Server Component rendering the client Explorer. Both `explorer` and `search` are already in `profiles_username_not_reserved` (applied 2026-08-04), so **no migration is needed**.

`AppNav`'s Explorer entry stops being a disabled label and becomes a real link.

### Data layer

- `lib/people.ts` (new): `containsPattern(query)` and `searchProfiles(client, query, limit = 20)` — an `or(...)` query over `profiles` ordered by username. Ports `PeopleSearchService`.
- `lib/explore.ts` (new): `fetchRecentMedia(client, kind, limit = 20)` — newest catalog rows of one kind. Ports `ExplorerService.recentMedia`, reusing `toMedia` from `lib/media.ts` so the decoder stays shared.
- Media search reuses `/api/catalog/search` unchanged. There is deliberately no second search path.

### Components

- `components/Explorer.tsx` — client component owning the selected category and query. One debounced search at 350ms, matching the composer and the onboarding username check.
- `components/CategoryChips.tsx` — the six chips.
- People results reuse the existing `ProfileRow` from Phase 3; media results reuse `CandidateList` from Phase 4 and the `MediaCover` tile for browse. **No new row or tile components** — everything Explorer needs already exists.

### What a result does

- A **person** links to `/[username]` — their profile, where the follow button and Venn overlap already live. That is the path out of the dead end.
- A **media item** links to `/composer?kind=<kind>&q=<title>`, which prefills the composer's category and query so the user picks it there and logs it. Prefilling by query rather than serializing the whole candidate keeps the URL short and shareable, and leaves exactly one way for a candidate to enter the composer — through its own search. The cost is one extra click versus iOS.

This requires a small change to `Composer.tsx`: read `kind` and `q` from search params as initial state. Reading them once as initial state (not syncing on every change) keeps the composer's existing state machine intact.

### Honesty about "Recommended for you"

iOS labels the browse panel "Recommended for you", but `ExplorerService.recentMedia` returns the newest catalog rows with no scoring — there is no recommendation engine behind it. Web uses **"Recently added"**, which describes what the list actually is.

This is a deliberate, documented deviation from rule 17's copy parity: matching the copy would mean shipping a claim the code does not support. Logged in `docs/TECH_DEBT.md` so the two get reconciled when real recommendations land — at which point iOS's label becomes true and web's should change to match.

## Error handling

Same pattern as every other web surface: a loading/loaded/error shape, errors mapped to copy at one boundary.

- The catalog is currently **empty** — zero media rows. Browse therefore shows "Nothing here yet — search to find something to log." rather than a blank panel. This is the expected state until people start logging, not an error.
- A people search that matches nobody shows "No one found." — not an error.
- A query that sanitizes to nothing (only punctuation, say) returns no results **without issuing a query**, mirroring iOS's empty-pattern guard.

## Testing

- **Unit (Vitest)**: `containsPattern` — that it strips PostgREST syntax characters (`,` `.` `(` `)` `'` `"` `*` `%`), keeps the username alphabet and accented letters, collapses whitespace, and returns `""` when nothing survives. `sanitizeSearchQuery`'s 100-character bound.
- **Component (RTL)**: category switching, that People and media categories render their respective result shapes, and that a media result links to the composer with the right prefill.
- **E2E (Playwright)**: `/explorer` redirects to `/login` when signed out.

The authenticated-session fixture gap (tech-debt row 13) still applies — signed-in behaviour is covered at component level.

## Open questions (not blocking)

- Ranked recommendations need a follow graph and interaction history that do not exist yet. `fetchRecentMedia`'s signature is deliberately the shape a scored version would keep, so the swap is an implementation change rather than an API change — the same bet `ExplorerServicing` documents on iOS.
