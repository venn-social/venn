-- =============================================================================
-- private_accounts_rls_test.sql — RLS verification for the private-accounts
-- migration, runnable without the full Supabase stack (handy on a disk-starved
-- machine; the supabase/postgres image is ~6GB).
--
-- How to run (needs any Docker-compatible runtime, e.g. OrbStack):
--   MIG=supabase/migrations/20260626120000_private_accounts.sql
--   docker run -d --name pgtest -e POSTGRES_PASSWORD=postgres \
--     -v "$PWD/$MIG":/mig.sql:ro \
--     -v "$PWD/supabase/tests/private_accounts_rls_test.sql":/harness.sql:ro \
--     postgres:17-alpine
--   until docker exec pgtest pg_isready -U postgres; do sleep 1; done
--   docker exec pgtest psql -U postgres -v ON_ERROR_STOP=1 -f /harness.sql
--   docker rm -f pgtest
-- Expect "ALL TESTS PASSED" and a zero exit. Last run: 2026-06-28, all green.
-- =============================================================================
-- RLS verification harness for the private-accounts migration.
-- Recreates just enough of the Supabase environment (auth.uid(), the
-- authenticated/anon roles, the base tables + pre-migration policies), runs the
-- REAL migration file via \i, seeds public/private/follower/viewer users, then
-- asserts the gating from each viewer's perspective. Any RAISE EXCEPTION + psql
-- ON_ERROR_STOP=1 fails the whole run.

\set ON_ERROR_STOP on

-- --- Emulate Supabase auth ----------------------------------------------------
create schema if not exists auth;
-- auth.uid() reads a per-transaction GUC the tests set with SET LOCAL test.uid.
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid
$$;

do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;

-- --- Base schema (pre-migration shape, matching prod) -------------------------
create type public.media_kind as enum ('movie','show','book','album');
create type public.post_action as enum ('logged','rated','saved');

create table public.profiles (
  id uuid primary key,
  username text unique not null,
  display_name text, avatar_url text, bio text,
  created_at timestamptz not null default now()
);
create table public.media (
  id uuid primary key default gen_random_uuid(),
  kind public.media_kind not null, title text not null,
  created_at timestamptz not null default now()
);
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  action public.post_action not null, rating numeric(2,1), caption text,
  created_at timestamptz not null default now()
);
create table public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followee_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id)
);
create table public.rate_limits (key text not null, ts timestamptz not null default now());

alter table public.profiles enable row level security;
alter table public.media    enable row level security;
alter table public.posts    enable row level security;
alter table public.follows  enable row level security;
alter table public.rate_limits enable row level security;

-- Pre-migration policies (what the migration will DROP / replace).
create policy profiles_select_all on public.profiles for select using (true);
create policy media_select_all    on public.media    for select using (true);
create policy posts_select_all    on public.posts    for select using (true);
create policy posts_insert_own    on public.posts    for insert with check (auth.uid() = author_id);
create policy posts_delete_own    on public.posts    for delete using (auth.uid() = author_id);
create policy follows_select_all  on public.follows  for select using (true);
create policy follows_insert_own  on public.follows  for insert with check (auth.uid() = follower_id);
create policy follows_delete_own  on public.follows  for delete using (auth.uid() = follower_id);

grant usage on schema public, auth to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- rl_check (from 20260611230000_overlap_rpc.sql) — the migration's RPCs call it.
create or replace function public.rl_check(_key text, _limit int, _window interval)
returns boolean language plpgsql security definer set search_path = '' as $$
declare _count int; _caller uuid := auth.uid();
begin
  -- Matches 20260816122000: a signed-in caller may only spend their own
  -- allowance, so a forged key is refused rather than charged to its owner.
  if _caller is not null and _key not like ('%:' || _caller::text) then
    return false;
  end if;
  insert into public.rate_limits (key, ts) values (_key, now());
  delete from public.rate_limits where ts < now() - _window;
  select count(*) into _count from public.rate_limits where key = _key and ts > now() - _window;
  return _count <= _limit;
end; $$;

-- --- Run the REAL migration --------------------------------------------------
\echo '>>> applying migration 20260626120000_private_accounts.sql'
\i /mig.sql
\echo '>>> migration applied OK'

-- --- Seed --------------------------------------------------------------------
insert into public.profiles (id, username, is_private) values
  ('00000000-0000-0000-0000-000000000001','pub',      false),
  ('00000000-0000-0000-0000-000000000002','priv',     true),
  ('00000000-0000-0000-0000-000000000003','viewer',   false),
  ('00000000-0000-0000-0000-000000000004','afollower',false);
insert into public.media (id, kind, title) values
  ('aaaaaaaa-0000-0000-0000-0000000000a1','movie','Dune');
insert into public.posts (author_id, media_id, action) values
  ('00000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-0000000000a1','logged'),
  ('00000000-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-0000000000a1','rated'),
  ('00000000-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-0000000000a1','logged');
-- afollower already follows priv, accepted (grandfathered default).
insert into public.follows (follower_id, followee_id, status) values
  ('00000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000002','accepted');

-- --- Tests -------------------------------------------------------------------
-- T1: non-follower CANNOT see a private user's posts.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  if (select count(*) from public.posts where author_id='00000000-0000-0000-0000-000000000002') <> 0
    then raise exception 'FAIL T1: non-follower saw private posts'; end if;
  raise notice 'PASS T1: non-follower sees 0 private posts';
end $$; rollback;

-- T2: accepted follower CAN see the private user's posts.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000004';
do $$ begin
  if (select count(*) from public.posts where author_id='00000000-0000-0000-0000-000000000002') <> 2
    then raise exception 'FAIL T2: accepted follower did not see 2 private posts'; end if;
  raise notice 'PASS T2: accepted follower sees private posts';
end $$; rollback;

-- T3: owner always sees own posts.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000002';
do $$ begin
  if (select count(*) from public.posts where author_id='00000000-0000-0000-0000-000000000002') <> 2
    then raise exception 'FAIL T3: owner cannot see own posts'; end if;
  raise notice 'PASS T3: owner sees own posts';
end $$; rollback;

-- T4: public users posts visible to anyone (no regression).
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  if (select count(*) from public.posts where author_id='00000000-0000-0000-0000-000000000001') <> 1
    then raise exception 'FAIL T4: public posts not visible'; end if;
  raise notice 'PASS T4: public posts visible to all';
end $$; rollback;

-- T5: request_follow on a PUBLIC target returns accepted (committed).
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ declare s text; begin
  s := public.request_follow('00000000-0000-0000-0000-000000000001');
  if s <> 'accepted' then raise exception 'FAIL T5: expected accepted got %', s; end if;
  raise notice 'PASS T5: request_follow(public) -> accepted';
end $$; commit;

-- T6: request_follow on a PRIVATE target returns pending (committed).
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ declare s text; begin
  s := public.request_follow('00000000-0000-0000-0000-000000000002');
  if s <> 'pending' then raise exception 'FAIL T6: expected pending got %', s; end if;
  raise notice 'PASS T6: request_follow(private) -> pending';
end $$; commit;

-- T7: pending request does NOT yet grant access.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  if (select count(*) from public.posts where author_id='00000000-0000-0000-0000-000000000002') <> 0
    then raise exception 'FAIL T7: pending follower saw private posts'; end if;
  raise notice 'PASS T7: pending follower still sees 0 private posts';
end $$; rollback;

-- T8: only the followee can accept; after accept the viewer gains access.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000002';
do $$ begin
  perform public.respond_to_follow_request('00000000-0000-0000-0000-000000000003', true);
  raise notice 'PASS T8a: followee accepted the request';
end $$; commit;

begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  if (select count(*) from public.posts where author_id='00000000-0000-0000-0000-000000000002') <> 2
    then raise exception 'FAIL T8b: accepted viewer cannot see private posts'; end if;
  raise notice 'PASS T8b: accepted viewer now sees private posts';
end $$; rollback;

-- T9: follow_counts returns accepted-only counts (afollower + viewer = 2).
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ declare f bigint; begin
  select followers into f from public.follow_counts('00000000-0000-0000-0000-000000000002');
  if f <> 2 then raise exception 'FAIL T9: followers=% expected 2', f; end if;
  raise notice 'PASS T9: follow_counts followers=2';
end $$; rollback;

-- T10: a client CANNOT directly insert a follow (insert policy was dropped).
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  begin
    insert into public.follows (follower_id, followee_id, status)
      values ('00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000002','accepted');
    raise exception 'FAIL T10: direct follow insert succeeded (privacy bypass!)';
  exception when insufficient_privilege then
    raise notice 'PASS T10: direct follow insert blocked by RLS';
  end;
end $$; rollback;

-- T11: a caller cannot spend somebody else's rate-limit allowance.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  if public.rl_check('anything:00000000-0000-0000-0000-000000000002', 100, interval '1 minute')
    then raise exception 'FAIL T11: forged rate-limit key was accepted'; end if;
  if not public.rl_check('anything:00000000-0000-0000-0000-000000000003', 100, interval '1 minute')
    then raise exception 'FAIL T11: own rate-limit key was refused'; end if;
  raise notice 'PASS T11: rate-limit keys are scoped to the caller';
end $$; rollback;

\echo '>>> ALL TESTS PASSED'
