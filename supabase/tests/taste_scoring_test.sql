-- =============================================================================
-- taste_scoring_test.sql — the hybrid scoring RPCs behave as the spec says.
--
-- The spec (§7) requires these to prove:
--   * with zero users, sim' = sim
--   * a seeded multi-user case moves α as specified
--   * a private account's posts never reach item_pair_evidence
--   * every result carries at least one why code
-- plus the usual: invoker RPCs, definer helpers that never hand out vectors,
-- the rate limit, and no access when signed out.
--
-- Same shape as the other harnesses: a hand-built base schema, the REAL
-- migrations applied with \i, RAISE EXCEPTION on failure. Needs pgvector,
-- so the image is pgvector/pgvector:pg17.
--
-- Run locally (needs any Docker-compatible runtime):
--   docker run -d --name scoretest -e POSTGRES_PASSWORD=postgres \
--     -v "$PWD/supabase/migrations/20260816122000_rl_check_rejects_forged_keys.sql":/mig.sql:ro \
--     -v "$PWD/supabase/migrations/20261124090000_taste_engine_schema.sql":/mig2.sql:ro \
--     -v "$PWD/supabase/migrations/20261124100000_taste_scoring.sql":/mig3.sql:ro \
--     -v "$PWD/supabase/tests/taste_scoring_test.sql":/harness.sql:ro \
--     pgvector/pgvector:pg17
--   until docker exec scoretest pg_isready -U postgres; do sleep 1; done
--   docker exec scoretest psql -U postgres -v ON_ERROR_STOP=1 -f /harness.sql
--   docker rm -f scoretest
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
alter default privileges in schema public grant all on tables to anon, authenticated;

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
create table public.rate_limits (key text not null, ts timestamptz not null default now());

alter table public.media enable row level security;
alter table public.posts enable row level security;
create policy media_select_all on public.media for select using (true);
-- The private-accounts policy, minus follows (no follower exists here).
create policy posts_select_visible on public.posts for select using (
  auth.uid() = author_id
  or exists (select 1 from public.profiles pr where pr.id = posts.author_id and pr.is_private = false)
);

-- --- Run the REAL migrations -------------------------------------------------
\echo '>>> applying 20260816122000_rl_check_rejects_forged_keys.sql'
\i /mig.sql
\echo '>>> applying 20261124090000_taste_engine_schema.sql'
\i /mig2.sql
\echo '>>> applying 20261124100000_taste_scoring.sql (twice: must replay)'
\i /mig3.sql
\i /mig3.sql
\echo '>>> migrations applied OK'

-- --- Fixtures ----------------------------------------------------------------
-- People: v = the viewer; u01..u10 public; p01..p03 private.
insert into public.profiles (id, username) values ('00000000-0000-0000-0000-0000000000a0', 'viewer');
insert into public.profiles (id, username)
  select ('00000000-0000-0000-0000-0000000001' || lpad(n::text, 2, '0'))::uuid, 'u' || n
    from generate_series(1, 10) n;
insert into public.profiles (id, username, is_private)
  select ('00000000-0000-0000-0000-0000000002' || lpad(n::text, 2, '0'))::uuid, 'p' || n, true
    from generate_series(1, 3) n;

-- Media. Names are the last two hex digits of the id.
--   a1 movie  — the viewer's Love (the anchor)
--   b1 movie  — shares a1's director and node
--   b2 book   — shares a1's node only (the cross-media one)
--   b3 album  — shares a1's node only
--   b4 movie  — shares a1's node; shares a director with the disliked d1
--   d1 movie  — the viewer's Dislike
--   f1, f2    — bare movies with year + commitment only (the formula check)
--   c1, c2    — co-liked by public users (the α check)
--   e1, e2    — co-liked by private users only
--   51        — already saved by the viewer (must be excluded)
--   61..65    — extra movies sharing a1's node (the per-kind cap)
insert into public.media (id, kind, title)
select ('10000000-0000-0000-0000-0000000000' || x.tag)::uuid, x.kind::public.media_kind, x.tag
  from (values ('a1','movie'),('b1','movie'),('b2','book'),('b3','album'),('b4','movie'),
               ('d1','movie'),('f1','movie'),('f2','movie'),('c1','movie'),('c2','book'),
               ('e1','movie'),('e2','book'),('51','movie'),
               ('61','movie'),('62','movie'),('63','movie'),('64','movie'),('65','movie')) x(tag, kind);

insert into public.taxonomy_nodes (slug, label_key, family) values ('drama','taxonomy.drama','drama');
insert into public.taxonomy_nodes (slug, label_key, parent_id, family)
  select 'coming-of-age','taxonomy.coming_of_age', id, 'drama' from public.taxonomy_nodes where slug='drama';

-- a1, b1..b4, d1 and 61..65 all carry the same node vector.
insert into public.media_taxonomy (media_id, node_id, weight)
select m.id, n.id, case n.slug when 'coming-of-age' then 0.8944 else 0.4472 end
  from public.media m cross join public.taxonomy_nodes n
 where m.title in ('a1','b1','b2','b3','b4','d1','61','62','63','64','65');

insert into public.people (id, tmdb_id, display_name) values
  ('20000000-0000-0000-0000-000000000001','1','Director One'),
  ('20000000-0000-0000-0000-000000000002','2','Director Two');
insert into public.media_people (media_id, person_id, role) values
  ('10000000-0000-0000-0000-0000000000a1','20000000-0000-0000-0000-000000000001','director'),
  ('10000000-0000-0000-0000-0000000000b1','20000000-0000-0000-0000-000000000001','director'),
  ('10000000-0000-0000-0000-0000000000d1','20000000-0000-0000-0000-000000000002','director'),
  ('10000000-0000-0000-0000-0000000000b4','20000000-0000-0000-0000-000000000002','director');

insert into public.media_features (media_id, year, decade, commitment, extractor_version) values
  ('10000000-0000-0000-0000-0000000000f1', 2000, 2000, 0.5, 1),
  ('10000000-0000-0000-0000-0000000000f2', 2008, 2000, 0.3, 1);

-- The viewer: loves a1, dislikes d1, saved 51.
insert into public.posts (author_id, media_id, action, rating) values
  ('00000000-0000-0000-0000-0000000000a0','10000000-0000-0000-0000-0000000000a1','rated',5),
  ('00000000-0000-0000-0000-0000000000a0','10000000-0000-0000-0000-0000000000d1','rated',1),
  ('00000000-0000-0000-0000-0000000000a0','10000000-0000-0000-0000-000000000051','saved',null);

-- --- Tests -------------------------------------------------------------------

-- T1: the RPCs are invoker; only the helpers that read private tables are
-- definer; the refresh is not callable by a client.
do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname = 'public' and p.proname in ('taste_recommendations','because_you_loved')
                and p.prosecdef) then
    raise exception 'FAIL T1: a public RPC is SECURITY DEFINER';
  end if;
  if (select array_agg(p.proname::text order by p.proname) from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
       where n.nspname = 'taste_internal' and p.prosecdef)
     <> array['embedding_cosines','nearest_to_seeds','pair_evidence','refresh_item_pair_evidence'] then
    raise exception 'FAIL T1: unexpected definer set in taste_internal';
  end if;
  if has_function_privilege('authenticated', 'taste_internal.refresh_item_pair_evidence()', 'execute') then
    raise exception 'FAIL T1: a client can rebuild pair evidence';
  end if;
  if has_schema_privilege('anon', 'taste_internal', 'usage') then
    raise exception 'FAIL T1: anon can reach taste_internal';
  end if;
  -- No helper returns a vector.
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
              where n.nspname in ('taste_internal','public')
                and pg_get_function_result(p.oid) like '%vector%') then
    raise exception 'FAIL T1: a function returns a vector';
  end if;
  raise notice 'PASS T1: invoker RPCs, narrow definer helpers, no vectors out';
end $$;

-- T2: signed out is refused.
begin; set local role authenticated; set local test.uid = '';
do $$
begin
  begin
    perform * from public.taste_recommendations();
    raise exception 'FAIL T2: signed-out caller got recommendations';
  exception when insufficient_privilege then null;
  end;
  begin
    perform * from public.because_you_loved();
    raise exception 'FAIL T2: signed-out caller got a shelf';
  exception when insufficient_privilege then null;
  end;
  raise notice 'PASS T2: signed-out callers are refused';
end $$;
commit;

-- T3: zero users — no evidence, α = 0, sim' = sim, and sim matches §2 by hand.
-- f1/f2 have only year (Δ 8) and commitment (Δ 0.2):
--   sim = (0.10·e^(−1) + 0.06·0.8) / (0.10 + 0.06)
do $$
declare got double precision; expected double precision := (0.10 * exp(-1.0) + 0.06 * 0.8) / 0.16;
begin
  if taste_internal.refresh_item_pair_evidence() <> 0 then
    raise exception 'FAIL T3: evidence from a single user';
  end if;
  select sim into got from taste_internal.pair_scores(
    array['10000000-0000-0000-0000-0000000000f1'::uuid], array['10000000-0000-0000-0000-0000000000f2'::uuid]);
  if abs(got - expected) > 1e-6 then  -- commitment is stored as real
    raise exception 'FAIL T3: sim % <> expected %', got, expected;
  end if;
  raise notice 'PASS T3: with zero users sim'' = sim = % (by hand)', round(got::numeric, 6);
end $$;

-- T4: ten public users like c1 and c2 → n_ab = 10, α = 10 / (10 + k=10) = 0.5,
-- collab = 10 / sqrt(10·10) = 1, so sim' = 0.5·sim + 0.5. c1/c2 have no
-- features, so sim is 0 and sim' must be exactly 0.5.
insert into public.posts (author_id, media_id, action, rating)
select u.id, m.id, 'rated', 5
  from public.profiles u cross join public.media m
 where u.username like 'u%' and m.title in ('c1','c2');
do $$
declare got double precision; reasons jsonb;
begin
  perform taste_internal.refresh_item_pair_evidence();
  if not exists (select 1 from public.item_pair_evidence where n_ab = 10 and n_a = 10 and n_b = 10) then
    raise exception 'FAIL T4: evidence not written as n_ab = n_a = n_b = 10';
  end if;
  select sim, why into got, reasons from taste_internal.pair_scores(
    array['10000000-0000-0000-0000-0000000000c1'::uuid], array['10000000-0000-0000-0000-0000000000c2'::uuid]);
  if abs(got - 0.5) > 1e-9 then
    raise exception 'FAIL T4: sim'' = %, expected 0.5', got;
  end if;
  if reasons <> '[{"code": "loved_by_similar"}]'::jsonb then
    raise exception 'FAIL T4: expected loved_by_similar only, got %', reasons;
  end if;
  -- And with features, the blend is exact: f1 → f2 has no evidence, so it
  -- stays sim; lowering k to 5 moves α on c1 → c2 to 10/15.
  update public.taste_weights set k = 5 where active;
  select sim into got from taste_internal.pair_scores(
    array['10000000-0000-0000-0000-0000000000c1'::uuid], array['10000000-0000-0000-0000-0000000000c2'::uuid]);
  if abs(got - 10.0 / 15.0) > 1e-9 then
    raise exception 'FAIL T4: α did not follow k: %', got;
  end if;
  update public.taste_weights set k = 10 where active;
  raise notice 'PASS T4: α = n/(n+k) moves the blend exactly';
end $$;

-- T5: a private account's likes never reach item_pair_evidence — not as a
-- pair, and not in the per-item counts.
insert into public.posts (author_id, media_id, action, rating)
select u.id, m.id, 'rated', 5
  from public.profiles u cross join public.media m
 where u.username like 'p%' and m.title in ('e1','e2','c1');
do $$
begin
  perform taste_internal.refresh_item_pair_evidence();
  if exists (select 1 from public.item_pair_evidence
              where a in ('10000000-0000-0000-0000-0000000000e1','10000000-0000-0000-0000-0000000000e2')
                 or b in ('10000000-0000-0000-0000-0000000000e1','10000000-0000-0000-0000-0000000000e2')) then
    raise exception 'FAIL T5: private likes produced a pair';
  end if;
  if exists (select 1 from public.item_pair_evidence where n_a <> 10 or n_b <> 10) then
    raise exception 'FAIL T5: private likes leaked into the per-item counts';
  end if;
  raise notice 'PASS T5: private accounts never reach item_pair_evidence';
end $$;

-- T6: the full profile — excludes what the viewer touched, every result has a
-- why, crosses media, and the dislike pushes its neighbour down.
begin; set local role authenticated; set local test.uid = '00000000-0000-0000-0000-0000000000a0';
do $$
declare r record; n int := 0; b1 double precision; b4 double precision; kinds int;
begin
  for r in select * from public.taste_recommendations(30) loop
    n := n + 1;
    if r.media_id in ('10000000-0000-0000-0000-0000000000a1','10000000-0000-0000-0000-0000000000d1',
                      '10000000-0000-0000-0000-000000000051') then
      raise exception 'FAIL T6: recommended something the viewer already has';
    end if;
    if jsonb_array_length(r.why) < 1 or not (r.why -> 0 ? 'code') then
      raise exception 'FAIL T6: % has no why code', r.media_id;
    end if;
    if r.weights_version <> 1 then raise exception 'FAIL T6: weights_version %', r.weights_version; end if;
  end loop;
  if n = 0 then raise exception 'FAIL T6: no recommendations'; end if;
  select count(distinct kind) into kinds from public.taste_recommendations(30);
  if kinds < 3 then raise exception 'FAIL T6: only % kinds — not cross-media', kinds; end if;
  -- b4 and 61 are alike in every way that relates them to the Love; b4
  -- alone also shares a director with the Dislike.
  select score into b1 from public.taste_recommendations(30) where media_id = '10000000-0000-0000-0000-000000000061';
  select score into b4 from public.taste_recommendations(30) where media_id = '10000000-0000-0000-0000-0000000000b4';
  if b1 is null or (b4 is not null and b4 >= b1) then
    raise exception 'FAIL T6: dislike did not push b4 (%) below its twin 61 (%)', b4, b1;
  end if;
  raise notice 'PASS T6: % results across % kinds, each with a why; the dislike subtracts', n, kinds;
end $$;
commit;

-- T7: the shelf — anchored on the Love, at most two per kind, shared person
-- explained, and every result explained.
begin; set local role authenticated; set local test.uid = '00000000-0000-0000-0000-0000000000a0';
do $$
declare worst int; top jsonb;
begin
  if exists (select 1 from public.because_you_loved(8)
              where anchor_media_id <> '10000000-0000-0000-0000-0000000000a1') then
    raise exception 'FAIL T7: anchor is not the Love';
  end if;
  select max(c) into worst from (select count(*) c from public.because_you_loved(8) group by kind) x;
  if worst > 2 then raise exception 'FAIL T7: % of one kind in the top 8', worst; end if;
  if exists (select 1 from public.because_you_loved(8) where jsonb_array_length(why) < 1) then
    raise exception 'FAIL T7: a shelf item has no why';
  end if;
  select why into top from public.because_you_loved(8) where media_id = '10000000-0000-0000-0000-0000000000b1';
  if not exists (select 1 from jsonb_array_elements(top) e where e ->> 'code' = 'shared_person') then
    raise exception 'FAIL T7: b1 shares the director but says %', top;
  end if;
  if (select count(*) from public.because_you_loved(8) where kind in ('book','album')) < 2 then
    raise exception 'FAIL T7: the shelf did not cross media';
  end if;
  raise notice 'PASS T7: shelf anchored, capped per kind, crosses media, explained';
end $$;
commit;

-- T8: no Love and no Like → no shelf.
insert into public.profiles (id, username) values ('00000000-0000-0000-0000-0000000000b0', 'blank');
begin; set local role authenticated; set local test.uid = '00000000-0000-0000-0000-0000000000b0';
do $$
begin
  if exists (select 1 from public.because_you_loved(8)) or exists (select 1 from public.taste_recommendations()) then
    raise exception 'FAIL T8: a person with no history got recommendations';
  end if;
  raise notice 'PASS T8: no history, no shelf';
end $$;
commit;

-- T9: embeddings — the term joins only when vectors exist, and on its own it
-- explains itself as embedding_close; the ANN step finds the neighbour.
insert into public.media_embeddings (media_id, embedding, model, input_hash)
select m.id, (select array_agg(case when i = 1 then 1.0 when i = 2 then v else 0 end)::real[]
                from generate_series(1, 64) i)::extensions.vector, 'm', repeat('a', 64)
  from (values ('f1', 0.0), ('c2', 0.1)) x(tag, v)
  join public.media m on m.title = x.tag;
do $$
declare reasons jsonb; near uuid[];
begin
  select why into reasons from taste_internal.pair_scores(
    array['10000000-0000-0000-0000-0000000000f1'::uuid], array['10000000-0000-0000-0000-0000000000c2'::uuid]);
  if reasons <> '[{"code": "embedding_close"}]'::jsonb then
    raise exception 'FAIL T9: expected embedding_close, got %', reasons;
  end if;
  select array_agg(media_id) into near from taste_internal.nearest_to_seeds(
    array['10000000-0000-0000-0000-0000000000f1'::uuid], array[1.0::double precision], 10,
    array['10000000-0000-0000-0000-0000000000f1'::uuid]);
  if near is distinct from array['10000000-0000-0000-0000-0000000000c2'::uuid] then
    raise exception 'FAIL T9: nearest_to_seeds returned %', near;
  end if;
  raise notice 'PASS T9: the embedding term and ANN step work once vectors exist';
end $$;

-- T10: rate-limited at 30 a minute, shared across both RPCs.
begin; set local role authenticated; set local test.uid = '00000000-0000-0000-0000-0000000000a0';
do $$
declare refused boolean := false;
begin
  begin
    for i in 1..31 loop
      perform * from public.because_you_loved(8);
    end loop;
  exception when sqlstate 'P0429' then refused := true;
  end;
  if not refused then raise exception 'FAIL T10: not rate-limited'; end if;
  raise notice 'PASS T10: rate-limited per caller';
end $$;
rollback;

\echo '>>> all taste scoring tests passed'
