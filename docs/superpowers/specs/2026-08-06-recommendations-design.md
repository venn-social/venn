# Recommendations — design

**Status:** approved 2026-08-06
**Surface:** Explorer tab, under the search bar, on iOS and web

---

## The problem

venn asks people to log what they consume, then gives them nowhere to go next. The Explorer tab's browse grid shows the newest rows in the catalog — unranked, unpersonalised, identical for everyone. iOS labels that grid "Recommended for you", which is a claim the code does not support (tech-debt row 18).

This replaces it with a real recommendation surface.

## The constraint that shapes everything

As of 2026-08-06 the production database holds:

|                                      |                             |
| ------------------------------------ | --------------------------- |
| `media` rows                         | 3                           |
| `posts`                              | 3, all rated, from 1 author |
| `profiles` / `follows`               | 3 / 1                       |
| `media` rows with `genres` populated | 0                           |

Collaborative filtering has nothing to filter on. "Trending on venn" would mean trending among three rows. The genre-clustering pipeline (`scripts/genre-clustering/`, Leiden communities → `media.genres`, wired to a GitHub Action) has never populated anything, because clustering three items is meaningless.

So the cold-start path is not a safety net here — it is the entire product until venn has users. The design is judged on two things: how good it is with no data, and how gracefully it climbs as data arrives.

**The discovery that makes this viable today:** TMDB exposes a real per-title `/recommendations` endpoint. "Because you loved _Past Lives_" needs no other venn users at all — it borrows collaborative filtering already computed from millions of TMDB users. The feature is genuinely useful from a user's **first log**, not months from now.

## Decisions taken

| Question              | Decision                                                                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Scope                 | Build the full tier ladder now; put the effort into the cold-start tier, since that is what runs. Higher tiers activate on their own as data arrives — no second project. |
| Where the logic lives | Postgres RPC for venn-data tiers, plus a thin per-client top-up from the catalog APIs.                                                                                    |
| Presentation          | Grouped, labelled shelves.                                                                                                                                                |
| Media kinds           | All four, with labels honest about what each shelf actually is.                                                                                                           |

### Why RPC over an Edge Function

Recommendations derive from other people's logs, so the privacy boundary is load-bearing. A `security invoker` RPC inherits the existing RLS policies: a private account's posts are already invisible to non-followers, so they cannot leak into anyone's recommendations. No new policy, nothing to get wrong.

An Edge Function would have to re-establish that boundary by hand — and would be the first in the repo, adding a deploy step, a third home for the TMDB key, and a cold start on every Explorer open.

The cost of this choice is that shelf assembly lives on both platforms. That cost is contained deliberately — see "Containing the drift".

## The tier ladder

Ordered by how much venn knows about the user. Tiers 1, 2 and 4 produce at most one shelf each; tier 3 produces one shelf **per seed**, which is why the 4-shelf cap in assembly matters.

| #   | Tier                      | Shelf copy                                 | Minimum data                   | Live today |
| --- | ------------------------- | ------------------------------------------ | ------------------------------ | ---------- |
| 1   | Taste twins               | "Popular with people who match your taste" | ~5 users with overlapping logs | No         |
| 2   | People you follow         | "Loved by people you follow"               | 1 follow, 1 log by them        | Almost     |
| 3   | Similar to what you loved | "More like {title}"                        | **1 log**                      | **Yes**    |
| 4   | Trending                  | "Trending this week"                       | none                           | **Yes**    |

Tier 2 is the sleeper: it needs only a follow graph, not taste similarity, so it activates far earlier than tier 1.

Tiers 1 and 2 come from the RPC. Tiers 3 and 4 come from the catalog APIs, per client.

### Tier 1 — taste twins

A `similar_users(_limit int)` helper ranks other users by Jaccard similarity over consumed sets, reusing the definition `compute_overlap` already established: consumed means `action in ('logged','rated')`, excluding `saved`. Their loved and liked items that the viewer has not consumed become the shelf, ordered by how many twins share them.

Runs `security invoker`, so the candidate pool is exactly the set of users whose posts RLS already permits.

### Tier 2 — people you follow

Items rated like or love (`rating >= 3`; dislike is 1) by accepted followees, excluding anything the viewer has consumed or saved, ordered by the followee's `posts.created_at` descending.

### Tier 3 — similar to what you loved

Per media kind, using the catalog the item came from:

| Kind         | Source                                              | Shelf copy                                 | Honest?                              |
| ------------ | --------------------------------------------------- | ------------------------------------------ | ------------------------------------ |
| movie / show | TMDB `/{movie\|tv}/{id}/recommendations`            | "More like {title}"                        | Yes — real similar-title data        |
| book         | OpenLibrary: same author's works, then same subject | "More from {author}" / "More in {subject}" | States what it is; not a taste match |
| album        | MusicBrainz: the artist's other release-groups      | "More from {artist}"                       | States what it is; not a taste match |

Seeds are the viewer's items rated like or love (`rating >= 3`), ordered by `posts.created_at` descending, capped at 5. Only items with both `external_source` and `external_id` qualify — a hand-typed row has no catalog to ask.

### Tier 4 — trending

| Kind         | Source                                          |
| ------------ | ----------------------------------------------- |
| movie / show | TMDB `/trending/all/week`                       |
| book         | OpenLibrary `/trending/weekly.json`             |
| album        | **None** — MusicBrainz has no popularity signal |

Music gets no trending shelf rather than a fabricated one.

## Exclusions

Applied to every tier, without exception:

- anything the viewer has logged or rated
- anything on their watchlist (`action = 'saved'`) — they already intend to
- anything they rated dislike (`rating = 1`)

**A dislike hides that item, not things like it.** With three rating values and sparse data, propagating negatives over-filters fast: "you disliked one Marvel film, so we hid all of them" is a worse failure than showing one more the viewer does not love. Revisit when ratings carry more information.

## The RPC contract

`public.recommendation_feed(_seed_limit int default 5, _per_section int default 12) returns jsonb`

`security invoker`, `stable`, granted to `authenticated` only.

```jsonc
{
  "sections": [
    {
      "source": "taste_twins",
      "items": [
        /* media rows */
      ]
    },
    {
      "source": "followed",
      "items": [
        /* media rows */
      ]
    }
  ],
  "seeds": [
    {
      "media_id": "…",
      "title": "Past Lives",
      "kind": "movie",
      "external_source": "tmdb",
      "external_id": "666277",
      "rating": 5.0
    }
  ],
  "excluded": [{ "source": "tmdb", "id": "666277" }]
}
```

**No user-facing English in SQL.** The RPC returns a `source` discriminator; each client maps it to copy. That keeps rule 17's copy-parity check in the two clients, where it already lives.

The exclusion key is `source:kind:id`, matching web's existing `candidateId()`. `kind` is load-bearing, not decoration: TMDB numbers movies and TV independently, so movie 123 and show 123 are different things that would otherwise collide. (iOS's `MediaCandidate.id` currently omits `kind` — a latent bug this work has to fix first, since the key must be byte-identical on both platforms.)

`excluded` exists because the client cannot filter TMDB results server-side. It is capped at the viewer's 500 most recent items by `posts.created_at` — a bound, not a guess: past that, TMDB's own result sets are small enough that a rare duplicate is better than an unbounded payload on every Explorer open.

Empty `sections` and empty `seeds` are normal, not errors. A brand-new user gets `{"sections": [], "seeds": [], "excluded": []}` and sees only the trending shelf.

## Client assembly

Given the RPC payload and whatever the catalog APIs returned, each client:

1. builds shelves from `sections`
2. builds one shelf per seed from that seed's similar-items call
3. builds the trending shelf
4. filters every externally-sourced item through `excluded`
5. dedups across shelves — first shelf wins
6. drops any shelf with fewer than 3 items
7. keeps at most 4 shelves, in tier order: taste twins → followed → similar-to-loved → trending. Within tier 3, seeds are ordered by rating then recency, so the cap drops the weakest seeds rather than a whole tier. Trending is appended last but is never dropped when it is the only surviving shelf — a user with no shelves at all falls through to the browse grid, which is a worse outcome than one filler row.

Rules 6 and 7 are what stop the Netflix-shelf layout from degenerating into a wall of empty rows — the failure mode flagged when this presentation was chosen.

## Containing the drift

Step-by-step assembly above is the only logic living in two places. It is therefore isolated into a **pure function** on each platform:

```
assembleShelves(payload, candidates) -> [Shelf]
```

No network, no UI, no clock. The same test cases run on both sides:

- an item excluded by `excluded` never appears
- an item in two tiers appears only in the highest
- a 2-item shelf is dropped; a 3-item shelf is kept
- a 5th shelf is dropped
- shelves come back in tier order
- an empty payload with no candidates yields no shelves at all

Everything around that function is platform-native and tested the way each platform already tests.

## File structure

```
supabase/migrations/<ts>_recommendations.sql   similar_users() + recommendation_feed()

web/lib/recommendations.ts                     types + assembleShelves (pure)
web/lib/catalog/similar.ts                     per-provider similar + trending fetchers
web/components/RecommendationShelves.tsx       the shelves
web/components/Explorer.tsx                    renders them under the search bar

ios/Venn/Features/Explorer/Recommendations/
  RecommendationService.swift                  the RPC + catalog calls
  RecommendationAssembler.swift                assembleShelves (pure)
  RecommendationsViewModel.swift               LoadState machine
  RecommendationShelfView.swift                one shelf
  RecommendationsView.swift                    the stack of shelves
```

iOS follows rule 16: a feature subfolder, one file per component. The Explorer feature folder is already large, which is why recommendations get their own subfolder rather than more files beside `ExplorerView.swift`.

## States

Uses the shared `LoadState` machine (`ios/Venn/Models/LoadState.swift`) rather than a new per-feature enum.

| State              | iOS                                      | Web                                       |
| ------------------ | ---------------------------------------- | ----------------------------------------- |
| Loading            | `DeferredLoadingView`                    | skeleton shelves                          |
| Loaded, shelves    | the shelves                              | the shelves                               |
| Loaded, no shelves | fall through to the existing browse grid | same                                      |
| Error              | `ErrorStateView` with retry              | inline message, browse grid still renders |

A catalog API failing degrades to fewer shelves, never to an error: the RPC tiers and the other catalogs are independent, so one provider being down costs one shelf. Only a failure of the RPC itself is an error state, and even then the browse grid below still renders.

## Testing

| Layer             | How                                                                                                                                                                                          |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `assembleShelves` | Pure unit tests, identical cases both platforms. Carries the real coverage.                                                                                                                  |
| Catalog fetchers  | Mapping tests over recorded payloads, as `MediaDetailMappingTests` / `detail.test.ts` do.                                                                                                    |
| View-models       | Fakes behind the service protocol (ADR 0005).                                                                                                                                                |
| SQL               | No SQL test harness exists in this repo. Verified by the authenticated Playwright suite asserting the Explorer renders shelves for a signed-in user, plus manual checks against seeded data. |

The SQL gap is real and worth naming: `recommendation_feed` is the one piece with no automated correctness test. It is also the piece most likely to be wrong, since it is the only new query joining across users. Manual verification before merge, and a tech-debt row for a SQL test harness.

## Performance

`similar_users` scans posts across users. At current scale this is free; at 10k users it is not. The RPC caps the candidate scan and returns at most `_per_section` items per tier. When that stops being enough, the fix is a materialised similarity table refreshed on a schedule — the RPC signature does not have to change for that, so it is deliberately not built now.

Catalog calls are one per seed plus one for trending — at most 6 per Explorer open. Both platforms already cache HTTP responses (iOS `URLCache`, sized at boot in `VennApp`; web `fetch` caching). No new cache layer.

## Explicitly out of scope

- **Push/email digests of recommendations.** Notifications are pull-only (tech-debt row 28).
- **Learning from what the user ignores.** No impression tracking; there is no data to learn from and it is a privacy surface worth deciding on deliberately.
- **Using `media.genres`.** The column and its clustering pipeline exist but are unpopulated. When the corpus is big enough for clustering to mean something, genres become a natural fifth tier — the ladder is designed to take one.
- **Ranking within a shelf beyond the stated ordering.** No learned weights.

## Consequences

- Tech-debt row 18 closes: iOS's "Recommended for you" becomes a true statement.
- The Explorer browse grid stays as the fallback beneath the shelves rather than being deleted.
- On the founding account this will look thin — a trending shelf, and one "more like" shelf after logging something. That is correct behaviour at three media rows, not a bug.
