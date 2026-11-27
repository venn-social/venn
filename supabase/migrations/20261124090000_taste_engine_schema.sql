-- =============================================================================
-- 20261124090000_taste_engine_schema.sql — storage for the taste engine.
-- =============================================================================
-- Step 2 of docs/superpowers/specs/2026-11-17-taste-engine-design.md (§6).
-- Schema only: no catalog data is written here. The tables are filled by
-- re-runnable server-side scripts (feature extraction, the vibe pass, the
-- embedding pass) and read by the scoring RPC, each in its own PR.
--
-- Who can do what, in one place:
--
--   catalog features   taxonomy_nodes, taxonomy_mappings, people,
--                      media_people, media_features, media_taxonomy,
--                      media_vibes, taste_weights
--                      → anyone may read; nobody writes from a client. They
--                        describe shared catalog rows, so a client that could
--                        write them could rewrite them for every user.
--   private internals  media_embeddings, item_pair_evidence
--                      → no client access at all. Vectors are only reached
--                        through RPCs that return ids and distances; pair
--                        evidence is aggregate and only read by definer code.
--   rec_events         → each person reads and writes only their own rows,
--                        rate-limited at insert like every other write.
--
-- One deliberate gap: media_embeddings.embedding has no fixed dimension and
-- no HNSW index yet. The dimension depends on which hosted model is chosen
-- (the spec's open question 1). pgvector can only index a column of fixed
-- dimension, so the index lands with the embedding pass, as
-- `using hnsw ((embedding::extensions.vector(D)) vector_cosine_ops)`, once D
-- is known. Nothing reads embeddings before then, so nothing is slow.
--
-- Idempotent: safe to replay.
-- =============================================================================

create extension if not exists vector with schema extensions;

-- -----------------------------------------------------------------------------
-- Taxonomy — one tree of nodes that mean the same thing in every medium (§1.3).
-- -----------------------------------------------------------------------------
create table if not exists public.taxonomy_nodes (
  id bigint generated always as identity primary key,
  slug text not null unique,
  -- A copy key, never English: the clients own the words (rule 17).
  label_key text not null,
  parent_id bigint references public.taxonomy_nodes(id) on delete restrict,
  -- The top-level family slug. A family node names itself.
  family text not null,
  -- null = applies to every kind. Otherwise the kinds the node may describe,
  -- so `shoegaze` can exist for albums without a novel pretending to be one.
  kind_scope public.media_kind[],
  constraint taxonomy_nodes_slug_format check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint taxonomy_nodes_family_format check (family ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  constraint taxonomy_nodes_label_key_length check (length(label_key) between 1 and 120),
  constraint taxonomy_nodes_no_self_parent check (parent_id is null or parent_id <> id),
  constraint taxonomy_nodes_scope_nonempty check (
    kind_scope is null or cardinality(kind_scope) between 1 and 4
  )
);

create index if not exists taxonomy_nodes_parent_idx on public.taxonomy_nodes (parent_id);

-- Catalog vocabulary → node. Lives in a table so curating a keyword list is a
-- data change, not a deploy.
create table if not exists public.taxonomy_mappings (
  source text not null,
  source_key text not null,
  node_id bigint not null references public.taxonomy_nodes(id) on delete cascade,
  weight real not null default 1,
  primary key (source, source_key, node_id),
  constraint taxonomy_mappings_source check (source in (
    'tmdb_genre', 'tmdb_keyword', 'openlibrary_subject', 'musicbrainz_genre', 'musicbrainz_tag'
  )),
  constraint taxonomy_mappings_key_length check (length(source_key) between 1 and 200),
  constraint taxonomy_mappings_weight_range check (weight > 0 and weight <= 1)
);

create index if not exists taxonomy_mappings_node_idx on public.taxonomy_mappings (node_id);

-- -----------------------------------------------------------------------------
-- People — one row per real person across every catalog (§1.2).
-- -----------------------------------------------------------------------------
-- Never merged by name: two different "John Williams" live in exactly these
-- catalogs. Identity is a Wikidata QID when a catalog links one, otherwise a
-- per-catalog id. Each id is unique on its own, so a person reached from two
-- catalogs through the same QID is one row.
create table if not exists public.people (
  id uuid primary key default gen_random_uuid(),
  wikidata_qid text unique,
  tmdb_id text unique,
  openlibrary_id text unique,
  musicbrainz_id text unique,
  display_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint people_has_identity check (
    wikidata_qid is not null or tmdb_id is not null
    or openlibrary_id is not null or musicbrainz_id is not null
  ),
  constraint people_qid_format check (wikidata_qid is null or wikidata_qid ~ '^Q[1-9][0-9]*$'),
  constraint people_tmdb_format check (tmdb_id is null or tmdb_id ~ '^[0-9]{1,12}$'),
  constraint people_openlibrary_format check (
    openlibrary_id is null or openlibrary_id ~ '^OL[0-9]+A$'
  ),
  constraint people_musicbrainz_format check (
    musicbrainz_id is null
    or musicbrainz_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  ),
  constraint people_display_name_length check (length(display_name) between 1 and 200)
);

do $$ begin
  create type public.person_role as enum (
    'director', 'author', 'primary_artist', 'tv_creator', 'composer',
    'screenwriter', 'producer', 'cast', 'translator'
  );
exception when duplicate_object then null; end $$;

create table if not exists public.media_people (
  media_id uuid not null references public.media(id) on delete cascade,
  person_id uuid not null references public.people(id) on delete cascade,
  role public.person_role not null,
  -- Cast order, 1-based. Only cast is billed; the spec counts billing 1–5.
  billing smallint,
  primary key (media_id, person_id, role),
  constraint media_people_billing check (
    (role = 'cast' and billing between 1 and 500) or (role <> 'cast' and billing is null)
  )
);

create index if not exists media_people_person_idx on public.media_people (person_id);

-- -----------------------------------------------------------------------------
-- Per-item features (§1.1, §1.4–1.6).
-- -----------------------------------------------------------------------------
create table if not exists public.media_features (
  media_id uuid primary key references public.media(id) on delete cascade,
  year smallint,
  decade smallint,
  -- The raw length in the kind's own unit (minutes for films, shows and
  -- albums; pages for books). Kept so commitment can be recomputed as the
  -- catalog grows without asking the providers again.
  length_raw real,
  -- Percentile of length_raw within its kind, in [0, 1] (§1.4).
  commitment real,
  language text,
  countries text[] not null default '{}',
  sound_tags text[] not null default '{}',
  extracted_at timestamptz not null default now(),
  extractor_version smallint not null,
  constraint media_features_year_range check (year is null or year between 1800 and 2200),
  constraint media_features_decade check (
    decade is null or (decade % 10 = 0 and year is not null and decade = year - year % 10)
  ),
  constraint media_features_length_positive check (length_raw is null or length_raw > 0),
  constraint media_features_commitment_range check (
    commitment is null or (commitment >= 0 and commitment <= 1)
  ),
  constraint media_features_language_format check (language is null or language ~ '^[a-z]{2}$'),
  constraint media_features_countries_format check (
    cardinality(countries) <= 20
    and array_to_string(countries, ',') ~ '^([A-Z]{2}(,[A-Z]{2})*)?$'
  ),
  constraint media_features_sound_vocabulary check (
    sound_tags <@ array[
      'guitar', 'synth', 'strings', 'piano', 'brass', 'voice-led', 'energy_low', 'energy_high'
    ]::text[]
  ),
  constraint media_features_extractor_version check (extractor_version >= 1)
);

-- The item's taxonomy vector, already propagated to parents (§1.3).
create table if not exists public.media_taxonomy (
  media_id uuid not null references public.media(id) on delete cascade,
  node_id bigint not null references public.taxonomy_nodes(id) on delete cascade,
  weight real not null,
  primary key (media_id, node_id),
  constraint media_taxonomy_weight_range check (weight > 0 and weight <= 1)
);

create index if not exists media_taxonomy_node_idx on public.media_taxonomy (node_id);

-- -----------------------------------------------------------------------------
-- Vibe — the AI pass (§1.7).
-- -----------------------------------------------------------------------------
-- The fixed mood and theme lists are owned by the vibe pass, which drops
-- anything outside them before writing. The database holds the shape: slugs
-- only, never free text, and the cardinalities the spec allows.
create table if not exists public.media_vibes (
  media_id uuid primary key references public.media(id) on delete cascade,
  moods text[] not null,
  pace real not null,
  tone real not null,
  intensity real not null,
  themes text[] not null,
  model text not null,
  prompt_version smallint not null,
  input_hash text not null,
  created_at timestamptz not null default now(),
  constraint media_vibes_moods_count check (cardinality(moods) between 1 and 3),
  constraint media_vibes_themes_count check (cardinality(themes) between 1 and 5),
  constraint media_vibes_slugs check (
    array_to_string(moods || themes, ',') ~ '^[a-z]+(-[a-z]+)*(,[a-z]+(-[a-z]+)*)*$'
  ),
  constraint media_vibes_scales check (
    pace between 0 and 1 and tone between 0 and 1 and intensity between 0 and 1
  ),
  constraint media_vibes_model_length check (length(model) between 1 and 100),
  constraint media_vibes_prompt_version check (prompt_version >= 1),
  constraint media_vibes_hash_format check (input_hash ~ '^[0-9a-f]{64}$')
);

-- -----------------------------------------------------------------------------
-- Embeddings (§1.8). No client access — see the header for why no index yet.
-- -----------------------------------------------------------------------------
create table if not exists public.media_embeddings (
  media_id uuid primary key references public.media(id) on delete cascade,
  embedding extensions.vector not null,
  model text not null,
  input_hash text not null,
  created_at timestamptz not null default now(),
  constraint media_embeddings_dims check (
    extensions.vector_dims(embedding) between 64 and 4096
  ),
  constraint media_embeddings_model_length check (length(model) between 1 and 100),
  constraint media_embeddings_hash_format check (input_hash ~ '^[0-9a-f]{64}$')
);

-- -----------------------------------------------------------------------------
-- Weights — versioned, so tuning never needs a deploy and rollback is one row.
-- -----------------------------------------------------------------------------
-- Valid means: exactly the eight features of §2, each in [0, 1], summing to 1.
create or replace function public.taste_weights_are_valid(_weights jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(_weights) = 'object'
     and (select count(*) from jsonb_object_keys(_weights)) = 8
     and _weights ?& array[
       'taxonomy', 'vibe', 'embedding', 'people', 'time', 'origin', 'commitment', 'sound'
     ]
     and not exists (
       select 1 from jsonb_each(_weights) e
        where jsonb_typeof(e.value) <> 'number'
           or (e.value)::numeric < 0 or (e.value)::numeric > 1
     )
     and abs((select sum((e.value)::numeric) from jsonb_each(_weights) e) - 1) <= 0.001;
$$;

create table if not exists public.taste_weights (
  version int primary key,
  weights jsonb not null,
  -- k in α = n / (n + k) for the collaborative term (§4.1).
  k real not null default 10,
  created_at timestamptz not null default now(),
  active boolean not null default false,
  constraint taste_weights_version_positive check (version >= 1),
  constraint taste_weights_shape check (public.taste_weights_are_valid(weights)),
  constraint taste_weights_k_positive check (k > 0)
);

-- At most one version is live at a time.
create unique index if not exists taste_weights_one_active
  on public.taste_weights (active) where active;

-- Version 1 is the spec's default table (§2). It is part of the definition of
-- the engine, the way a column default is, not a correction to stored data.
-- `do nothing` keeps a replay from resetting a tuned version.
insert into public.taste_weights (version, weights, k, active)
values (
  1,
  '{"taxonomy": 0.22, "vibe": 0.20, "embedding": 0.15, "people": 0.15,
    "time": 0.10, "origin": 0.07, "commitment": 0.06, "sound": 0.05}'::jsonb,
  10,
  true
)
on conflict (version) do nothing;

-- -----------------------------------------------------------------------------
-- Collaborative evidence (§4.1). Aggregate counts only, never per-person.
-- -----------------------------------------------------------------------------
-- Stored once per unordered pair (a < b). n_a and n_b ride along so the
-- cosine n_ab / sqrt(n_a · n_b) needs no second lookup. A pair is only kept
-- at n_ab ≥ 3, so no row can single out one person's taste.
create table if not exists public.item_pair_evidence (
  a uuid not null references public.media(id) on delete cascade,
  b uuid not null references public.media(id) on delete cascade,
  n_ab int not null,
  n_a int not null,
  n_b int not null,
  updated_at timestamptz not null default now(),
  primary key (a, b),
  constraint item_pair_evidence_ordered check (a < b),
  constraint item_pair_evidence_floor check (n_ab >= 3),
  constraint item_pair_evidence_counts check (n_a >= n_ab and n_b >= n_ab)
);

create index if not exists item_pair_evidence_b_idx on public.item_pair_evidence (b);

-- -----------------------------------------------------------------------------
-- Feedback log (§5).
-- -----------------------------------------------------------------------------
create table if not exists public.rec_events (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  surface text not null,
  anchor_media_id uuid references public.media(id) on delete set null,
  rank smallint not null,
  score real not null,
  why jsonb not null default '[]',
  weights_version int not null references public.taste_weights(version),
  shown_at timestamptz not null default now(),
  opened_at timestamptz,
  acted_at timestamptz,
  action public.post_action,
  rating numeric(2, 1),
  constraint rec_events_surface check (surface in ('because_you_loved')),
  constraint rec_events_rank_range check (rank between 0 and 100),
  constraint rec_events_score_finite check (score between -1 and 1),
  constraint rec_events_why_shape check (
    jsonb_typeof(why) = 'array' and jsonb_array_length(why) <= 4
  ),
  constraint rec_events_opened_after_shown check (opened_at is null or opened_at >= shown_at),
  constraint rec_events_rating_range check (rating is null or (rating >= 0 and rating <= 5))
);

create index if not exists rec_events_user_media_idx on public.rec_events (user_id, media_id);
create index if not exists rec_events_media_idx on public.rec_events (media_id);
create index if not exists rec_events_anchor_idx on public.rec_events (anchor_media_id);
create index if not exists rec_events_weights_version_idx on public.rec_events (weights_version);

-- Rate limit at the API boundary (rule 8). A trigger rather than an RPC, so
-- a plain PostgREST insert from either client meets it.
create or replace function public.enforce_rec_event_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Keyed on the caller, not on new.user_id: a row claiming to be someone
  -- else's spends the caller's own allowance, then RLS refuses it. Keying on
  -- the claimed owner would let that forgery spend another person's limit.
  -- The service role has no uid and falls back to the row's owner.
  if not public.rl_check(
    'rec_event:' || coalesce((select auth.uid()), new.user_id)::text, 120, interval '1 minute'
  ) then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  return new;
end;
$$;

drop trigger if exists rec_events_rate_limit on public.rec_events;
create trigger rec_events_rate_limit
  before insert on public.rec_events
  for each row execute function public.enforce_rec_event_rate_limit();

-- Outcome capture: when the person logs, saves or rates something a shelf
-- showed them in the last 14 days, the matching events record it (§4.2's
-- positive outcome window). Definer, because clients may not write these
-- columns themselves — an outcome a client can forge would train the weights
-- on whatever it said.
create or replace function public.record_rec_event_outcome()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.rec_events e
     set acted_at = now(),
         action = new.action,
         rating = new.rating
   where e.user_id = new.author_id
     and e.media_id = new.media_id
     and e.acted_at is null
     and e.shown_at > now() - interval '14 days';
  return null;
end;
$$;

drop trigger if exists posts_record_rec_outcome on public.posts;
create trigger posts_record_rec_outcome
  after insert or update of action, rating on public.posts
  for each row execute function public.record_rec_event_outcome();

-- Trigger functions are not RPCs; nobody calls them directly.
revoke execute on function public.enforce_rec_event_rate_limit() from public, anon, authenticated;
revoke execute on function public.record_rec_event_outcome() from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Row-Level Security.
-- -----------------------------------------------------------------------------
alter table public.taxonomy_nodes enable row level security;
alter table public.taxonomy_mappings enable row level security;
alter table public.people enable row level security;
alter table public.media_people enable row level security;
alter table public.media_features enable row level security;
alter table public.media_taxonomy enable row level security;
alter table public.media_vibes enable row level security;
alter table public.media_embeddings enable row level security;
alter table public.taste_weights enable row level security;
alter table public.item_pair_evidence enable row level security;
alter table public.rec_events enable row level security;

-- Catalog features: public read, no client writes (no write policies exist,
-- so RLS refuses every insert, update and delete from anon/authenticated).
drop policy if exists taxonomy_nodes_select_all on public.taxonomy_nodes;
create policy taxonomy_nodes_select_all on public.taxonomy_nodes for select using (true);

drop policy if exists taxonomy_mappings_select_all on public.taxonomy_mappings;
create policy taxonomy_mappings_select_all on public.taxonomy_mappings for select using (true);

drop policy if exists people_select_all on public.people;
create policy people_select_all on public.people for select using (true);

drop policy if exists media_people_select_all on public.media_people;
create policy media_people_select_all on public.media_people for select using (true);

drop policy if exists media_features_select_all on public.media_features;
create policy media_features_select_all on public.media_features for select using (true);

drop policy if exists media_taxonomy_select_all on public.media_taxonomy;
create policy media_taxonomy_select_all on public.media_taxonomy for select using (true);

drop policy if exists media_vibes_select_all on public.media_vibes;
create policy media_vibes_select_all on public.media_vibes for select using (true);

drop policy if exists taste_weights_select_all on public.taste_weights;
create policy taste_weights_select_all on public.taste_weights for select using (true);

-- Private internals: RLS on with no policies, and the grants removed too, so
-- a future permissive policy added by mistake still exposes nothing.
revoke all on public.media_embeddings from anon, authenticated;
revoke all on public.item_pair_evidence from anon, authenticated;

-- rec_events: owner-only. Clients insert a row when a shelf renders and set
-- opened_at when an item is opened — and nothing else. Score, rank, why and
-- the outcome columns are written once or by the trigger above.
drop policy if exists rec_events_select_own on public.rec_events;
create policy rec_events_select_own on public.rec_events for select
  to authenticated using (user_id = (select auth.uid()));

drop policy if exists rec_events_insert_own on public.rec_events;
create policy rec_events_insert_own on public.rec_events for insert
  to authenticated with check (
    user_id = (select auth.uid())
    and opened_at is null and acted_at is null and action is null and rating is null
  );

drop policy if exists rec_events_update_own on public.rec_events;
create policy rec_events_update_own on public.rec_events for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

revoke all on public.rec_events from anon;
revoke update on public.rec_events from authenticated;
grant select, insert on public.rec_events to authenticated;
grant update (opened_at) on public.rec_events to authenticated;
