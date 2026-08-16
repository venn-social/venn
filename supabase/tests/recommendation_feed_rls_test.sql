-- =============================================================================
-- recommendation_feed_rls_test.sql — the privacy boundary the recommendation
-- shelves depend on, checked automatically instead of by hand.
--
-- `recommendation_feed` is the only query that joins across users, and so the
-- one most able to leak another account's activity. It was verified once, by
-- hand, on the day it shipped. Nothing stopped that regressing.
--
-- Follows the shape of private_accounts_rls_test.sql: no Supabase stack and no
-- pgTAP, just a plain postgres image, a hand-built base schema, the REAL
-- migration applied with \i, and RAISE EXCEPTION for failures.
--
-- Run locally (needs any Docker-compatible runtime):
--   docker run -d --name rectest -e POSTGRES_PASSWORD=postgres \
--     -v "$PWD/supabase/migrations/20260806120000_recommendations.sql":/mig.sql:ro \
--     -v "$PWD/supabase/tests/recommendation_feed_rls_test.sql":/harness.sql:ro \
--     postgres:17-alpine
--   until docker exec rectest pg_isready -U postgres; do sleep 1; done
--   docker exec rectest psql -U postgres -v ON_ERROR_STOP=1 -f /harness.sql
--   docker rm -f rectest
-- =============================================================================

\set ON_ERROR_STOP on

-- --- Emulate Supabase auth ----------------------------------------------------
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid
$$;

do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;

-- --- Base schema, matching prod at the point this migration lands -------------
create type public.media_kind as enum ('movie','show','book','album');
create type public.post_action as enum ('logged','rated','saved');

create table public.profiles (
  id uuid primary key,
  username text unique not null,
  is_private boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.media (
  id uuid primary key default gen_random_uuid(),
  kind public.media_kind not null,
  title text not null,
  year int,
  primary_creator text,
  cover_url text,
  external_source text,
  external_id text,
  genres text[],
  created_at timestamptz not null default now()
);
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  action public.post_action not null,
  rating numeric(2,1),
  caption text,
  created_at timestamptz not null default now()
);
create table public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followee_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'accepted',
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id)
);

alter table public.profiles enable row level security;
alter table public.media    enable row level security;
alter table public.posts    enable row level security;
alter table public.follows  enable row level security;

create policy profiles_select_all on public.profiles for select using (true);
create policy media_select_all    on public.media    for select using (true);
create policy follows_select_all  on public.follows  for select using (true);

-- The gate under test. Copied from the private-accounts migration, because
-- that is the policy the recommendation queries inherit by being
-- `security invoker` — if they ever stop inheriting it, these tests fail.
create policy posts_select_visible on public.posts for select using (
  auth.uid() = author_id
  or exists (select 1 from public.profiles pr where pr.id = posts.author_id and pr.is_private = false)
  or exists (
    select 1 from public.follows f
     where f.followee_id = posts.author_id
       and f.follower_id = auth.uid()
       and f.status = 'accepted'
  )
);

grant usage on schema public, auth to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- --- Run the REAL migration --------------------------------------------------
\echo '>>> applying migration 20260806120000_recommendations.sql'
\i /mig.sql
\echo '>>> migration applied OK'

-- --- Seed --------------------------------------------------------------------
-- viewer follows nobody. priv is private. pub is public. Both have logged the
-- same film as viewer, which is what would make them a "taste twin".
insert into public.profiles (id, username, is_private) values
  ('00000000-0000-0000-0000-000000000001','viewer', false),
  ('00000000-0000-0000-0000-000000000002','priv',   true),
  ('00000000-0000-0000-0000-000000000003','pub',    false);

insert into public.media (id, kind, title, external_source, external_id) values
  ('aaaaaaaa-0000-0000-0000-0000000000a1','movie','Shared',  'tmdb','1'),
  ('aaaaaaaa-0000-0000-0000-0000000000a2','movie','PrivPick','tmdb','2'),
  ('aaaaaaaa-0000-0000-0000-0000000000a3','movie','PubPick', 'tmdb','3');

insert into public.posts (author_id, media_id, action, rating) values
  -- The overlap that makes both look similar to viewer. The viewer's is
  -- rated, not merely logged: seeds require rating >= 3, because "more like
  -- this" needs an opinion to work from, and something you only logged
  -- expresses none.
  ('00000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-0000000000a1','rated', 5),
  ('00000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-0000000000a1','logged', null),
  ('00000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-0000000000a1','logged', null),
  -- What each of them additionally likes, and might therefore recommend.
  ('00000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-0000000000a2','rated', 5),
  ('00000000-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-0000000000a3','rated', 5);

-- --- Tests -------------------------------------------------------------------

-- T1: the function must be security invoker. This is the single change that
-- would break every other guarantee here at once, and it is a one-word edit.
do $$
declare is_definer boolean;
begin
  select p.prosecdef into is_definer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'recommendation_feed';
  if is_definer is null then raise exception 'FAIL T1: recommendation_feed missing'; end if;
  if is_definer then raise exception 'FAIL T1: recommendation_feed is SECURITY DEFINER'; end if;
  raise notice 'PASS T1: recommendation_feed is security invoker';
end $$;

do $$
declare is_definer boolean;
begin
  select p.prosecdef into is_definer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'similar_users';
  if is_definer then raise exception 'FAIL T1b: similar_users is SECURITY DEFINER'; end if;
  raise notice 'PASS T1b: similar_users is security invoker';
end $$;

-- T2: a private stranger never appears as a taste twin.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare found int;
begin
  select count(*) into found
    from public.similar_users(20) s
   where s.user_id = '00000000-0000-0000-0000-000000000002';
  if found <> 0 then raise exception 'FAIL T2: private stranger surfaced as a similar user'; end if;
  raise notice 'PASS T2: private stranger is not a similar user';
end $$; rollback;

-- T3: a public stranger with the same taste DOES appear. Without this, T2
-- would also pass on a function that simply returned nothing.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare found int;
begin
  select count(*) into found
    from public.similar_users(20) s
   where s.user_id = '00000000-0000-0000-0000-000000000003';
  if found <> 1 then raise exception 'FAIL T3: public stranger did not surface as a similar user'; end if;
  raise notice 'PASS T3: public stranger is a similar user';
end $$; rollback;

-- T4: nothing a private stranger logged reaches the viewer's feed.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare payload jsonb;
begin
  payload := public.recommendation_feed(8, 12);
  if payload::text like '%PrivPick%' then
    raise exception 'FAIL T4: private stranger''s pick leaked into the feed';
  end if;
  raise notice 'PASS T4: private stranger''s pick absent from the feed';
end $$; rollback;

-- T5: the viewer's own activity still drives the feed, so T4 is not passing
-- merely because the feed is empty. Seeds come from rated rows only, which is
-- why the viewer's overlap above carries a rating.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare payload jsonb;
begin
  payload := public.recommendation_feed(8, 12);
  if jsonb_array_length(coalesce(payload -> 'seeds', '[]'::jsonb)) = 0 then
    raise exception 'FAIL T5: viewer has logged something but produced no seeds';
  end if;
  raise notice 'PASS T5: the viewer''s own activity produces seeds';
end $$; rollback;

-- T6: once the private user accepts a follow, their picks may be used.
insert into public.follows (follower_id, followee_id, status) values
  ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002','accepted');

begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare found int;
begin
  select count(*) into found
    from public.similar_users(20) s
   where s.user_id = '00000000-0000-0000-0000-000000000002';
  if found <> 1 then raise exception 'FAIL T6: accepted follow did not grant visibility'; end if;
  raise notice 'PASS T6: accepted follower is a similar user';
end $$; rollback;

-- T7: a pending request grants nothing. This is the subtle one — "asked to
-- follow" and "follows" are easy to conflate in a predicate.
update public.follows set status = 'pending'
 where follower_id = '00000000-0000-0000-0000-000000000001'
   and followee_id = '00000000-0000-0000-0000-000000000002';

begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare found int;
begin
  select count(*) into found
    from public.similar_users(20) s
   where s.user_id = '00000000-0000-0000-0000-000000000002';
  if found <> 0 then raise exception 'FAIL T7: pending request granted visibility'; end if;
  raise notice 'PASS T7: pending request grants nothing';
end $$; rollback;

\echo 'ALL TESTS PASSED'
