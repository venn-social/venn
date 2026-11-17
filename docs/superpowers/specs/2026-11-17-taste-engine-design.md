# Taste engine — design

**Status:** draft, awaiting Charles's approval (approved once this PR merges)
**Source:** the "venn taste engine" section of the HQ page _december plan_ (16 Nov 2026), with Charles's decisions of the same day
**Surface:** a "Because you loved {title}" shelf that crosses media types, on iOS and web; and every later recommendation surface

---

## The problem

The recommendations shipped in August (`2026-08-06-recommendations-design.md`) borrow similarity from each catalog: TMDB's `/recommendations` for films, "more by this author" for books, and "more by this artist" for albums. That works on day one, but it can never cross media. TMDB knows nothing about novels, and Open Library knows nothing about albums. The cross-media recommendation, "loved _Past Lives_ → this novel, this album", is the headline of the launch, and no catalog will hand it to us.

So venn needs its own model of what an item _is_, in one space shared by films, shows, books and albums.

## Principles (Charles, 16 Nov)

1. **Intrinsic first.** Recommendations come from the characteristics of each item, compared by explicit, explainable rules. The engine works with zero users.
2. **Users reinforce; they are not required.** Collaborative evidence is computed from day one, but its weight is zero until evidence exists, and it grows on its own as evidence arrives. No code change is needed for that.
3. **Built once, before launch.** Default weights are sensible by hand, and they are tuned automatically from feedback, within safe bounds.
4. **Every recommendation can say why.** For example: "both slow-burn, 1970s, scored by the same composer".

Approved on 16 Nov: a **hosted** embedding provider, and **AI-written vibe descriptions** per item.

## Out of scope for December

- Audio analysis of tracks.
- Restaurants and games. The verticals stay movies, shows, books and albums.
- Any UI beyond the one shelf. Its visual design goes through the design-approval rule like every other surface.

---

## 1. Item features

Every `media` row gets one normalised feature record. Each field says where it comes from. "AI" means the vibe pass in §1.7; everything else is read from the catalog.

| Feature   | Movie / show (TMDB)                                    | Book (Open Library)      | Album (MusicBrainz)                                            |
| --------- | ------------------------------------------------------ | ------------------------ | -------------------------------------------------------------- |
| Year      | `release_date` / `first_air_date`                      | `first_publish_year`     | release-group `first-release-date`                             |
| Era       | decade + era node (§1.3)                               | same                     | same                                                           |
| People    | director, writers, composer, top-5 cast, creators (TV) | authors, translators     | artist credits, producers where tagged                         |
| Taxonomy  | genre ids + keywords → nodes                           | subjects → nodes         | genres + tags → nodes                                          |
| Length    | runtime (min); seasons × episode runtime (TV)          | `number_of_pages_median` | total length of the representative release                     |
| Origin    | `original_language`, `production_countries`            | edition languages        | artist `country`, release language                             |
| Sound     | —                                                      | —                        | MusicBrainz tags in the sound vocabulary (instruments, energy) |
| Vibe      | AI                                                     | AI                       | AI                                                             |
| Embedding | of the taste text (§1.8)                               | same                     | same                                                           |

A field the catalog doesn't have stays null. Similarity (§2) ignores a feature when either side lacks it and re-normalises the remaining weights. A missing field never counts as a mismatch.

### 1.1 Time

`year smallint`, `decade smallint` (e.g. 1970). An item also belongs to its era node in the taxonomy, such as _New Hollywood_ or _British Invasion_. Era nodes come from the taxonomy mappings, not from the year alone. For example, `noir` is a genre node and `classic-noir-era` is an era node.

### 1.2 People

One `people` table across media. A person who directed a film and wrote a novel should be one row, because cross-media links (author ↔ adaptation, composer ↔ score) are some of the strongest explanations available.

Identity, in order of trust:

1. Wikidata QID, when the catalog links one. TMDB `external_ids`, Open Library `remote_ids` and MusicBrainz URL relations all can.
2. A per-catalog id (`tmdb:person:525`, `openlibrary:OL23919A`, `musicbrainz:<mbid>`) when there is no QID.

People are never merged by name alone: two different "John Williams" exist in exactly these catalogs. `media_people` links items to people with a `role`, and each role has a weight:

| Role                                         | Weight |
| -------------------------------------------- | ------ |
| director, author, primary artist, TV creator | 1.0    |
| composer                                     | 0.8    |
| screenwriter, producer (music)               | 0.7    |
| lead cast (billing 1–5)                      | 0.5    |
| translator                                   | 0.2    |

### 1.3 The cross-media taxonomy

This is a two-level tree of nodes that mean the same thing in every medium. The point is that `noir` exists for a film, a novel and an album. Every node has a `kind_scope`, either `all` or a subset of kinds. That lets a medium-specific node like `shoegaze` exist without polluting cross-media comparisons.

Proposed top level, with 18 families:

| Family                 | Example children                                           |
| ---------------------- | ---------------------------------------------------------- |
| crime                  | noir, heist, detective, gangster, legal                    |
| thriller               | psychological, political, conspiracy, survival             |
| horror                 | supernatural, folk-horror, body-horror, gothic, slasher    |
| speculative            | science-fiction, cyberpunk, dystopia, space, time          |
| fantasy                | high-fantasy, fairy-tale, magical-realism, mythic          |
| drama                  | family, coming-of-age, character-study, melodrama          |
| romance                | romantic-comedy, tragic-romance, queer-romance             |
| comedy                 | satire, absurdist, dark-comedy, slapstick                  |
| war-history            | war, period, biography, historical-epic                    |
| adventure              | quest, western, swashbuckler, exploration                  |
| documentary-nonfiction | memoir, essay, true-crime, science, politics               |
| family-children        | animation, picture-book, kids                              |
| music-performance      | musical, concert, music-biography                          |
| literary-art           | experimental, minimalist, surreal, arthouse                |
| rock                   | punk, post-punk, indie, shoegaze _(album only)_            |
| electronic             | ambient, techno, house, synth-pop _(album only)_           |
| soul-hiphop            | hip-hop, r-and-b, soul, funk, jazz _(album only)_          |
| folk-classical         | folk, singer-songwriter, classical, country _(album only)_ |

The music families are scoped to albums. Films and books reach them through vibe and the music-performance family, not by pretending a novel is "shoegaze".

**Mappings** live in a table, not in code: `taxonomy_mappings(source, source_key, node_id, weight)`. The seed rows:

- **TMDB genre ids** (fixed list). Some examples:

  | TMDB genre             | Node(s)                         |
  | ---------------------- | ------------------------------- |
  | 80 Crime               | crime                           |
  | 9648 Mystery           | detective                       |
  | 878 Science Fiction    | science-fiction                 |
  | 27 Horror              | horror                          |
  | 10749 Romance          | romance                         |
  | 99 Documentary         | documentary-nonfiction          |
  | 16 Animation           | animation                       |
  | 10765 Sci-Fi & Fantasy | speculative 0.5 + fantasy 0.5   |
  | 10768 War & Politics   | war-history 0.5 + political 0.5 |

  All 27 movie and TV genre ids get a row.

- **TMDB keywords** for a curated list of about 200 keywords, such as `film noir`, `heist`, `dystopia` and `coming of age`. Unlisted keywords are ignored rather than guessed.
- **Open Library subjects**, matched case-insensitively against a curated list of about 300 subject strings. The format is the same (`detective and mystery stories` → detective). Subjects that are places or people (`London (England)`) are skipped.
- **MusicBrainz genres** (a controlled vocabulary, about 900 entries) mapped for the top ~250. **Tags** only when they also appear in the genre list, because tags are free text.

An item's taxonomy vector is the sum of its mapped node weights. Each node also contributes 0.5 of its weight to its parent, so _noir_ and _detective_ still meet at _crime_. The vector is L2-normalised.

### 1.4 Length → one "commitment" scale

Lengths aren't comparable across media, but how much of yourself an item asks for is. `commitment` is the item's **percentile within its kind**, in [0, 1], computed over the catalog:

- a 95-minute film ≈ 0.30
- a 600-page novel ≈ 0.85
- a 38-minute album ≈ 0.40
- a 6-season show ≈ 0.95

Percentiles are recomputed by the extraction script. Until a kind has 200 items with a length, a fixed reference table stands in.

### 1.5 Origin

`original_language` (ISO 639-1) and `countries text[]` (ISO 3166-1 alpha-2).

### 1.6 Sound (albums only)

A small controlled vocabulary drawn from MusicBrainz tags: instrument families (guitar, synth, strings, piano, brass, voice-led), plus `energy_low` and `energy_high`. There is no audio analysis in December, by Charles's call.

### 1.7 Vibe (AI pass)

One record per item, written by the hosted LLM from the item's catalog description. The same prompt is used for every medium, so the scales line up across media:

| Field       | Type                       | Meaning                                                                            |
| ----------- | -------------------------- | ---------------------------------------------------------------------------------- |
| `moods`     | 1–3 of a fixed list of 16  | e.g. melancholic, tense, playful, tender, eerie, euphoric, contemplative, angry    |
| `pace`      | 0–1                        | slow-burn → propulsive                                                             |
| `tone`      | 0–1                        | light → dark                                                                       |
| `intensity` | 0–1                        | gentle → overwhelming                                                              |
| `themes`    | 1–5 of a fixed list of ~60 | e.g. grief, first-love, class, identity, ambition, isolation, family, faith, power |

The rules for the vibe pass:

- **The output is validated against the schema and the fixed lists.** Anything outside a list is dropped, never stored as free text.
- Each record carries `model`, `prompt_version` and `input_hash`. Re-running skips an item whose hash and version are unchanged, so the pass is idempotent and cheap to repeat.
- **A cost cap is enforced per run** (max items and max spend, set by env var). The run stops cleanly at the cap and resumes on the next run.
- An item with no description gets no vibe, rather than one guessed from its title.

### 1.8 Embedding

The embedding input is a **taste text** assembled from the fields above, never from user content:

> {kind}. {title} ({year}). By {top people}. {taxonomy node labels}. {synopsis/first sentence, ≤ 600 chars}. Mood: {moods}. Themes: {themes}.

There is one model and one vector space for all kinds. The vector is stored as `vector(D)` with an HNSW index (cosine). `D` depends on the provider (open question 1). Like the vibe record, it carries `model` and `input_hash`, and the job is idempotent.

The embedding is **one signal among several** (§2), not the engine. It captures "aboutness" that the hand-built features miss, but alone it can't explain a recommendation.

---

## 2. Item-to-item similarity

```
sim(a, b) = Σ_f w_f · s_f(a, b) / Σ_f w_f        over features f present on both a and b
```

Every `s_f` is in [0, 1]. The table below gives each feature's formula and its default weight.

| Feature `f` | `s_f(a, b)`                                                                                                        | Default `w_f` |
| ----------- | ------------------------------------------------------------------------------------------------------------------ | ------------- |
| taxonomy    | cosine of the propagated node vectors (§1.3)                                                                       | 0.22          |
| vibe        | 0.4 · (1 − mean abs diff of pace, tone, intensity) + 0.3 · Jaccard(moods) + 0.3 · Jaccard(themes)                  | 0.20          |
| embedding   | max(0, (cos − 0.2) / 0.8). Raw cosine between unrelated items sits around 0.2 for most models, so this rescales it | 0.15          |
| people      | weighted Jaccard over person sets, using role weights (§1.2)                                                       | 0.15          |
| time        | exp(−\|year_a − year_b\| / 8), plus 0.1 if they share an era node, capped at 1                                     | 0.10          |
| origin      | 0.6 · [same language] + 0.4 · Jaccard(countries)                                                                   | 0.07          |
| commitment  | 1 − \|c_a − c_b\|                                                                                                  | 0.06          |
| sound       | Jaccard over sound tags (albums only, so only album ↔ album)                                                       | 0.05          |

The weights sum to 1.0. They live in a versioned `taste_weights` row, not in code, so tuning (§4.2) never needs a deploy.

**Within-kind bias.** Same-kind pairs naturally share more features: people, sound, and sometimes taxonomy scope. A "Because you loved" shelf is meant to cross media, so its candidate pool is drawn **per kind**, at least 3 per kind when available (§3.3). It is not one global top-N.

### 2.1 Explanations

Every score keeps its per-feature breakdown. The **why** is the two features with the highest `w_f · s_f`, as structured codes:

```jsonc
{
  "why": [
    { "code": "shared_person", "person_id": "…", "role_a": "composer", "role_b": "composer" },
    { "code": "shared_vibe", "moods": ["melancholic"], "pace": "slow" }
  ]
}
```

**No user-facing English is written in SQL.** That is the same rule as the August spec. Each client maps the codes to copy, so rule 17's copy parity stays in the clients. The codes are `shared_person`, `shared_node`, `shared_vibe`, `same_era`, `same_origin`, `similar_length`, `shared_sound`, `embedding_close` and `loved_by_similar`. The last two only appear when nothing more specific scored.

---

## 3. User taste profile and scoring

### 3.1 Signals

| Signal                 | Weight |
| ---------------------- | ------ |
| Love (`rating = 5`)    | +1.0   |
| Like (`rating = 3`)    | +0.6   |
| Logged, no rating      | +0.2   |
| Saved (watchlist)      | +0.1   |
| Dislike (`rating = 1`) | −0.8   |

Each signal decays by recency, with a half-life of 365 days on `posts.created_at`. Imported history (Letterboxd, Goodreads) is backdated to its real date, so a film loved in 2015 counts for less than one loved last month. That is the intended behaviour.

### 3.2 Scoring

The profile is the user's **top 50 signals by |weight × decay|**. These are seeds, not an averaged vector. Averaging blurs a person who loves both horror and romcoms into neither.

```
score(c) = Σ_i  w_i · decay_i · sim(seed_i, c)  /  Σ_i |w_i · decay_i|
```

Negative seeds subtract, which is how a dislike pushes away close neighbours. This differs from the August spec on purpose: a dislike there hides only the item itself, because with three rating values and no similarity model, propagating it over-filtered. Here the similarity is graded, so a dislike lowers near-identical items a lot and loosely related items barely at all.

### 3.3 Candidate generation (keeps the RPC fast)

Scoring every item against 50 seeds doesn't scale, so candidates come from three cheap sources, are unioned, and only then get the full `score`:

1. **ANN:** the 300 nearest items to the user's _taste centroid_. That is the weighted mean of positive seeds' embeddings, using the HNSW index.
2. **Overlap:** items sharing a person or a taxonomy node with any positive seed, top 200 by overlap count.
3. **Per-kind floor:** at least 20 per kind from (1) or (2), so the cross-media shelf always has non-film candidates when they exist.

The **exclusions** are the August spec's, unchanged: anything logged, rated or saved, and the item a dislike points at.

### 3.4 "Because you loved {title}"

This is the launch shelf. Pick the user's strongest recent Love as the anchor, rank candidates by `sim(anchor, c)` (not the full profile), keep at most 2 per kind in the top 8, and attach the why codes. If the user has no Love, use their strongest Like, and if there is none, show no shelf.

---

## 4. Built for users from day one

### 4.1 The collaborative term

For an item pair (a, b), evidence comes from people who rated both like-or-love:

```
n_ab       = number of users who liked both a and b
collab(a,b) = n_ab / sqrt(n_a · n_b)                    (cosine on co-likes)
α(a,b)      = n_ab / (n_ab + k),     k = 10
sim'(a, b)  = (1 − α) · sim(a, b) + α · collab(a, b)
```

With no users, `n_ab = 0`, so α = 0 and `sim' = sim` exactly. At 10 co-likers the two terms count equally, and beyond that the crowd gradually dominates, without anyone changing code. `k` lives in `taste_weights`.

**Privacy:**

- Pair counts come from posts that RLS lets the counting job see under the **public** policy, so private accounts never contribute.
- The job runs as a scheduled, security-definer function that writes only aggregate counts to `item_pair_evidence(a, b, n_ab)`.
- A pair is stored only once `n_ab ≥ 3`, so no row can single out one person's taste.

### 4.2 Learning the weights

Every shown recommendation is logged from launch (§5). Weekly, a job fits per-feature contributions against outcomes, where a positive outcome is: opened, then logged, saved or loved within 14 days.

The job only moves the weights within **safe bounds**:

- **No change until 500 outcomes exist.** Before that, the defaults stand.
- Each weight stays within [0.5×, 2×] of its default, and the set always sums to 1.
- Each weight moves at most 10% per week.
- Every change is a **new `taste_weights` version**. Rolling back means pointing at the previous version, which is one row.

---

## 5. Feedback log

`rec_events`:

| Column            | Notes                    |
| ----------------- | ------------------------ |
| `user_id`         |                          |
| `media_id`        |                          |
| `surface`         | e.g. `because_you_loved` |
| `anchor_media_id` |                          |
| `rank`            |                          |
| `score`           |                          |
| `why`             | the codes                |
| `weights_version` |                          |
| `shown_at`        |                          |
| `opened_at`       |                          |
| `acted_at`        |                          |
| `action`          | logged / saved / rated   |
| `rating`          |                          |

Access rules:

- RLS: insert and select own rows only.
- Rows are written by the clients when a shelf renders and when an item is opened. The `acted_at`/`action` columns are filled by a trigger on `posts`.
- Rate-limited at insert like every other write: `rl_check('rec_event:' || uid, 120, '1 minute')`.

---

## 6. Schema summary (for the schema task)

All of this is in migration files, never `db:push`ed by the agent.

| Table                | Contents                                                                                             | RLS              |
| -------------------- | ---------------------------------------------------------------------------------------------------- | ---------------- |
| `taxonomy_nodes`     | id, slug, label_key, parent_id, family, kind_scope                                                   | public read      |
| `taxonomy_mappings`  | source, source_key, node_id, weight                                                                  | public read      |
| `people`             | id, wikidata_qid, per-catalog ids, display name                                                      | public read      |
| `media_people`       | media_id, person_id, role, billing                                                                   | public read      |
| `media_features`     | media_id, year, decade, commitment, language, countries, sound_tags, extracted_at, extractor_version | public read      |
| `media_taxonomy`     | media_id, node_id, weight (propagated)                                                               | public read      |
| `media_vibes`        | media_id, moods, pace, tone, intensity, themes, model, prompt_version, input_hash                    | public read      |
| `media_embeddings`   | media_id, embedding vector(D), model, input_hash                                                     | no client access |
| `taste_weights`      | version, weights jsonb, k, created_at, active                                                        | public read      |
| `item_pair_evidence` | a, b, n_ab, updated_at                                                                               | no client access |
| `rec_events`         | §5                                                                                                   | owner only       |

Write access for every table except `rec_events` is server-side only (service role, or definer functions). Clients never write catalog features.

Access to embeddings is through RPCs only. Both the scoring RPC and the ANN step are `security invoker` (rule 8: rate-limited, `rl_check('taste_recs:' || uid, 30, '1 minute')`). They read embeddings through a narrow definer helper that returns ids and distances, never vectors.

## 7. Delivery, mapped to the existing tasks

| Step | Task                                                      | Depends on                                                                          |
| ---- | --------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 1    | this spec                                                 | —                                                                                   |
| 2    | add media features + embeddings schema (pgvector)         | this spec merged                                                                    |
| 3    | extract item features from tmdb, openlibrary, musicbrainz | 2 (can stack)                                                                       |
| 4    | generate vibe descriptions + embeddings (hosted)          | 2, provider key                                                                     |
| 5    | build hybrid scoring rpc with confidence-weighted users   | 2, 3 (can stack). The embedding term is weight 0 until step 4 has populated vectors |
| 6    | "Because you loved" shelf UI                              | 5, plus an approved design                                                          |

The SQL tests for step 5 must prove:

- with zero users, `sim' = sim`
- a seeded multi-user case moves α as specified
- a private account's posts never reach `item_pair_evidence`
- every result carries at least one why code

## Open questions for Charles

1. **Embedding provider and dimension.** The model choice sets `D` in the schema, so it's needed before step 2. Hosted is already approved; the specific provider and key are still to come.
2. **The neutral band.** The import PRs (#237, #238) treat 2.5–3 stars as "logged, no sentiment". If you'd rather 3 stars count as Like, that also changes the +0.2 vs +0.6 signal weight above.
3. **Imported history in the collaborative term.** This spec counts it, because it's real taste and it's what gives day-one users evidence. The alternative is to count only likes made inside venn.
4. **Taxonomy curation.** The ~200 TMDB keywords and ~300 Open Library subjects need a human pass. Should Claude draft the lists in the schema PR for you to edit?
