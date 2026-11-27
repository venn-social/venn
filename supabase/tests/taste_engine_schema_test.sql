-- =============================================================================
-- taste_engine_schema_test.sql — who may read and write the taste engine's
-- tables, and the shapes they refuse.
--
-- Same shape as the other harnesses here: a hand-built base schema, the REAL
-- migrations applied with \i, and RAISE EXCEPTION for failures. One
-- difference: the migration enables pgvector, so the image must ship it.
-- pgvector/pgvector:pg17 is postgres:17 plus the extension.
--
-- Run locally (needs any Docker-compatible runtime):
--   docker run -d --name tastetest -e POSTGRES_PASSWORD=postgres \
--     -v "$PWD/supabase/migrations/20260816122000_rl_check_rejects_forged_keys.sql":/mig.sql:ro \
--     -v "$PWD/supabase/migrations/20261124090000_taste_engine_schema.sql":/mig2.sql:ro \
--     -v "$PWD/supabase/tests/taste_engine_schema_test.sql":/harness.sql:ro \
--     pgvector/pgvector:pg17
--   until docker exec tastetest pg_isready -U postgres; do sleep 1; done
--   docker exec tastetest psql -U postgres -v ON_ERROR_STOP=1 -f /harness.sql
--   docker rm -f tastetest
-- =============================================================================

\set ON_ERROR_STOP on

-- --- Emulate Supabase --------------------------------------------------------
create schema if not exists auth;
create schema if not exists extensions;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid
$$;
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
grant usage on schema public, auth, extensions to anon, authenticated;
-- Supabase grants every new public table to the API roles by default and
-- leaves RLS to decide. Emulate that, so the migration's revokes are tested
-- against the real starting point rather than an already-locked table.
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;

-- --- Base schema, matching prod at the point this migration lands -----------
create type public.media_kind as enum ('movie','show','book','album');
create type public.post_action as enum ('logged','rated','saved');

create table public.profiles (
  id uuid primary key,
  username text unique not null,
  is_private boolean not null default false
);
create table public.media (
  id uuid primary key default gen_random_uuid(),
  kind public.media_kind not null,
  title text not null,
  year smallint,
  external_id text,
  external_source text,
  created_at timestamptz not null default now()
);
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  action public.post_action not null,
  rating numeric(2,1),
  created_at timestamptz not null default now(),
  constraint posts_one_per_author_media unique (author_id, media_id)
);
create table public.rate_limits (
  key text not null,
  ts timestamptz not null default now()
);

alter table public.posts enable row level security;
create policy posts_select_all on public.posts for select using (true);
create policy posts_insert_own on public.posts for insert with check (auth.uid() = author_id);
create policy posts_update_own on public.posts for update using (auth.uid() = author_id);

-- --- Run the REAL migrations -------------------------------------------------
\echo '>>> applying migration 20260816122000_rl_check_rejects_forged_keys.sql'
\i /mig.sql
\echo '>>> applying migration 20261124090000_taste_engine_schema.sql'
\i /mig2.sql
\echo '>>> applying it a second time (migrations must replay safely)'
\i /mig2.sql
\echo '>>> migrations applied OK'

insert into public.profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001','ada'),
  ('00000000-0000-0000-0000-000000000002','grace');
insert into public.media (id, kind, title) values
  ('10000000-0000-0000-0000-000000000001','movie','Past Lives'),
  ('10000000-0000-0000-0000-000000000002','book','Klara and the Sun'),
  ('10000000-0000-0000-0000-000000000003','album','Blue');

-- Server-side fixtures (the extraction script runs with the service role).
insert into public.taxonomy_nodes (slug, label_key, family) values ('drama','taxonomy.drama','drama');
insert into public.taxonomy_nodes (slug, label_key, parent_id, family)
  select 'character-study','taxonomy.character_study', id, 'drama' from public.taxonomy_nodes where slug='drama';
insert into public.people (id, wikidata_qid, display_name)
  values ('20000000-0000-0000-0000-000000000001','Q312258','Celine Song');
insert into public.media_people (media_id, person_id, role)
  values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','director');
insert into public.media_features (media_id, year, decade, length_raw, commitment, language, countries, extractor_version)
  values ('10000000-0000-0000-0000-000000000001', 2023, 2020, 106, 0.4, 'en', '{US,KR}', 1);
insert into public.media_embeddings (media_id, embedding, model, input_hash)
  values ('10000000-0000-0000-0000-000000000001',
          (select array_agg(0.1)::real[] from generate_series(1, 128))::extensions.vector,
          'test-model', repeat('a', 64));
insert into public.item_pair_evidence (a, b, n_ab, n_a, n_b)
  values ('10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002', 3, 5, 4);

-- --- Tests -------------------------------------------------------------------

-- T1: the catalog-feature tables are readable by anyone, signed in or not.
begin; set local role anon;
do $$
begin
  if (select count(*) from public.taxonomy_nodes) <> 2
     or (select count(*) from public.people) <> 1
     or (select count(*) from public.media_people) <> 1
     or (select count(*) from public.media_features) <> 1
     or (select count(*) from public.taste_weights) <> 1 then
    raise exception 'FAIL T1: anon cannot read the catalog-feature tables';
  end if;
  perform 1 from public.taxonomy_mappings;
  perform 1 from public.media_taxonomy;
  perform 1 from public.media_vibes;
  raise notice 'PASS T1: catalog features are public read';
end $$;
commit;

-- T2: no client can write a catalog-feature table — they describe rows every
-- user shares.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare refused int := 0;
begin
  begin insert into public.taxonomy_nodes (slug, label_key, family) values ('x','x','x');
  exception when insufficient_privilege then refused := refused + 1; end;
  begin insert into public.taxonomy_mappings (source, source_key, node_id)
          select 'tmdb_genre', '18', id from public.taxonomy_nodes limit 1;
  exception when insufficient_privilege then refused := refused + 1; end;
  begin insert into public.people (tmdb_id, display_name) values ('1','x');
  exception when insufficient_privilege then refused := refused + 1; end;
  begin insert into public.media_people (media_id, person_id, role)
          values ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','author');
  exception when insufficient_privilege then refused := refused + 1; end;
  begin insert into public.media_features (media_id, extractor_version)
          values ('10000000-0000-0000-0000-000000000002', 1);
  exception when insufficient_privilege then refused := refused + 1; end;
  begin insert into public.media_vibes (media_id, moods, pace, tone, intensity, themes, model, prompt_version, input_hash)
          values ('10000000-0000-0000-0000-000000000002','{tender}',0.2,0.3,0.4,'{grief}','m',1,repeat('b',64));
  exception when insufficient_privilege then refused := refused + 1; end;
  begin insert into public.taste_weights (version, weights)
          select 2, weights from public.taste_weights where version = 1;
  exception when insufficient_privilege then refused := refused + 1; end;
  if refused <> 7 then
    raise exception 'FAIL T2: only % of 7 client inserts were refused', refused;
  end if;

  update public.media_features set commitment = 1;
  update public.taste_weights set active = false;
  delete from public.people;
  if (select commitment from public.media_features) <> 0.4::real
     or not (select active from public.taste_weights where version = 1)
     or (select count(*) from public.people) <> 1 then
    raise exception 'FAIL T2: a client update or delete changed a catalog row';
  end if;
  raise notice 'PASS T2: clients cannot write catalog features';
end $$;
commit;

-- T3: embeddings and pair evidence are invisible to every client role.
do $$
declare r text; t text; refused int := 0;
begin
  foreach r in array array['anon','authenticated'] loop
    foreach t in array array['media_embeddings','item_pair_evidence'] loop
      begin
        execute format('set local role %I', r);
        execute format('select count(*) from public.%I', t);
      exception when insufficient_privilege then refused := refused + 1;
      end;
      reset role;
    end loop;
  end loop;
  if refused <> 4 then
    raise exception 'FAIL T3: only % of 4 private-table reads were refused', refused;
  end if;
  raise notice 'PASS T3: embeddings and pair evidence have no client access';
end $$;

-- T4: rec_events — a person writes and reads only their own rows.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
insert into public.rec_events (media_id, surface, anchor_media_id, rank, score, why, weights_version)
  values ('10000000-0000-0000-0000-000000000002','because_you_loved',
          '10000000-0000-0000-0000-000000000001', 0, 0.81,
          '[{"code":"shared_node","node":"character-study"}]', 1);
do $$
begin
  begin
    insert into public.rec_events (user_id, media_id, surface, rank, score, weights_version)
      values ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003',
              'because_you_loved', 1, 0.5, 1);
    raise exception 'FAIL T4: wrote a row for someone else';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.rec_events (media_id, surface, rank, score, weights_version, acted_at, action)
      values ('10000000-0000-0000-0000-000000000003','because_you_loved', 1, 0.5, 1, now(), 'rated');
    raise exception 'FAIL T4: a client forged an outcome at insert';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS T4: rec_events inserts are owner-only and outcome-free';
end $$;
commit;

begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000002';
do $$
begin
  if exists (select 1 from public.rec_events) then
    raise exception 'FAIL T5: grace can see ada''s rec_events';
  end if;
  update public.rec_events set opened_at = now();
  if exists (select 1 from public.rec_events where opened_at is not null) then
    raise exception 'FAIL T5: grace updated ada''s rec_events';
  end if;
  raise notice 'PASS T5: rec_events are invisible to other people';
end $$;
commit;

-- T6: the owner may mark an event opened, and change nothing else.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
begin
  update public.rec_events set opened_at = now();
  if not exists (select 1 from public.rec_events where opened_at is not null) then
    raise exception 'FAIL T6: the owner could not set opened_at';
  end if;
  begin
    update public.rec_events set score = 1;
    raise exception 'FAIL T6: the owner rewrote a score';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.rec_events set acted_at = now(), action = 'rated';
    raise exception 'FAIL T6: the owner forged an outcome';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS T6: only opened_at is client-writable';
end $$;
commit;

-- T7: logging the recommended item records the outcome on the event.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
insert into public.posts (author_id, media_id, action, rating)
  values ('00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','rated',5);
do $$
begin
  if not exists (
    select 1 from public.rec_events
     where media_id = '10000000-0000-0000-0000-000000000002'
       and acted_at is not null and action = 'rated' and rating = 5
  ) then
    raise exception 'FAIL T7: the outcome was not recorded';
  end if;
  raise notice 'PASS T7: a post records the outcome on its rec_event';
end $$;
commit;

-- T8: someone else logging the same item does not touch your event.
update public.rec_events set acted_at = null, action = null, rating = null;
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000002';
insert into public.posts (author_id, media_id, action)
  values ('00000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002','logged');
commit;
do $$
begin
  if exists (select 1 from public.rec_events where acted_at is not null) then
    raise exception 'FAIL T8: another person''s post wrote an outcome on ada''s event';
  end if;
  raise notice 'PASS T8: outcomes are only recorded for the event''s owner';
end $$;

-- T9: rec_events inserts are rate-limited per person (120 a minute).
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare refused boolean := false;
begin
  begin
    for i in 1..121 loop
      insert into public.rec_events (media_id, surface, rank, score, weights_version)
        values ('10000000-0000-0000-0000-000000000003','because_you_loved', 0, 0.1, 1);
    end loop;
  exception when sqlstate 'P0429' then refused := true;
  end;
  if not refused then
    raise exception 'FAIL T9: rec_events inserts were not rate-limited';
  end if;
  raise notice 'PASS T9: rec_events inserts are rate-limited';
end $$;
rollback;

-- T10: taste_weights only accepts the eight features, summing to 1, and only
-- one version can be live.
do $$
declare refused int := 0;
begin
  begin insert into public.taste_weights (version, weights) values (2, '{"taxonomy": 1}');
  exception when check_violation then refused := refused + 1; end;
  begin insert into public.taste_weights (version, weights)
          values (3, '{"taxonomy":0.5,"vibe":0.5,"embedding":0.5,"people":0,"time":0,"origin":0,"commitment":0,"sound":0}');
  exception when check_violation then refused := refused + 1; end;
  begin insert into public.taste_weights (version, weights)
          values (4, '{"taxonomy":"a","vibe":0.2,"embedding":0.15,"people":0.15,"time":0.1,"origin":0.07,"commitment":0.06,"sound":0.05}');
  exception when check_violation then refused := refused + 1; end;
  begin insert into public.taste_weights (version, weights, active)
          select 5, weights, true from public.taste_weights where version = 1;
  exception when unique_violation then refused := refused + 1; end;
  if refused <> 4 then
    raise exception 'FAIL T10: only % of 4 bad weight rows were refused', refused;
  end if;
  insert into public.taste_weights (version, weights)
    select 6, weights from public.taste_weights where version = 1;
  raise notice 'PASS T10: taste_weights rejects malformed or second-active versions';
end $$;

-- T11: shapes the spec forbids are refused at the database.
do $$
declare refused int := 0;
begin
  -- pair evidence: unordered duplicates, and pairs below the privacy floor
  begin insert into public.item_pair_evidence (a, b, n_ab, n_a, n_b)
          values ('10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001', 3, 3, 3);
  exception when check_violation then refused := refused + 1; end;
  begin insert into public.item_pair_evidence (a, b, n_ab, n_a, n_b)
          values ('10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000003', 2, 2, 2);
  exception when check_violation then refused := refused + 1; end;
  -- vibes: free text and out-of-range scales
  begin insert into public.media_vibes (media_id, moods, pace, tone, intensity, themes, model, prompt_version, input_hash)
          values ('10000000-0000-0000-0000-000000000002','{"very sad!"}',0.2,0.3,0.4,'{grief}','m',1,repeat('b',64));
  exception when check_violation then refused := refused + 1; end;
  begin insert into public.media_vibes (media_id, moods, pace, tone, intensity, themes, model, prompt_version, input_hash)
          values ('10000000-0000-0000-0000-000000000002','{tender}',1.5,0.3,0.4,'{grief}','m',1,repeat('b',64));
  exception when check_violation then refused := refused + 1; end;
  -- features: a sound tag outside the vocabulary, a decade that disagrees with the year
  begin insert into public.media_features (media_id, sound_tags, extractor_version)
          values ('10000000-0000-0000-0000-000000000003','{kazoo}',1);
  exception when check_violation then refused := refused + 1; end;
  begin insert into public.media_features (media_id, year, decade, extractor_version)
          values ('10000000-0000-0000-0000-000000000003',1971,1980,1);
  exception when check_violation then refused := refused + 1; end;
  -- people: no identity at all, and a malformed QID
  begin insert into public.people (display_name) values ('John Williams');
  exception when check_violation then refused := refused + 1; end;
  begin insert into public.people (wikidata_qid, display_name) values ('john','John Williams');
  exception when check_violation then refused := refused + 1; end;
  -- media_people: billing only for cast
  begin insert into public.media_people (media_id, person_id, role, billing)
          values ('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','author',1);
  exception when check_violation then refused := refused + 1; end;
  -- embeddings: an absurd dimension
  begin insert into public.media_embeddings (media_id, embedding, model, input_hash)
          values ('10000000-0000-0000-0000-000000000002','[1,2,3]','m',repeat('c',64));
  exception when check_violation then refused := refused + 1; end;
  if refused <> 10 then
    raise exception 'FAIL T11: only % of 10 malformed rows were refused', refused;
  end if;
  raise notice 'PASS T11: malformed feature rows are refused';
end $$;

\echo '>>> all taste engine schema tests passed'
