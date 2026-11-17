-- =============================================================================
-- import_library_test.sql — bulk import is idempotent, backdated, and still
-- rate-limited, without opening a hole in the per-post limit.
--
-- Same shape as the other harnesses here: a plain postgres image, a
-- hand-built base schema, the REAL migrations applied with \i, and RAISE
-- EXCEPTION for failures.
--
-- Run locally (needs any Docker-compatible runtime):
--   docker run -d --name importtest -e POSTGRES_PASSWORD=postgres \
--     -v "$PWD/supabase/migrations/20260816122000_rl_check_rejects_forged_keys.sql":/mig.sql:ro \
--     -v "$PWD/supabase/migrations/20260804180000_post_rate_limit.sql":/mig2.sql:ro \
--     -v "$PWD/supabase/migrations/20261117090000_import_library.sql":/mig3.sql:ro \
--     -v "$PWD/supabase/tests/import_library_test.sql":/harness.sql:ro \
--     postgres:17-alpine
--   until docker exec importtest pg_isready -U postgres; do sleep 1; done
--   docker exec importtest psql -U postgres -v ON_ERROR_STOP=1 -f /harness.sql
--   docker rm -f importtest
-- =============================================================================

\set ON_ERROR_STOP on

-- --- Emulate Supabase auth ----------------------------------------------------
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid
$$;
do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;

-- --- Base schema, matching prod at the point this migration lands -----------
create type public.media_kind as enum ('movie','show','book','album');
create type public.post_action as enum ('logged','rated','saved');

create table public.profiles (
  id uuid primary key,
  username text unique not null
);
create table public.media (
  id uuid primary key default gen_random_uuid(),
  kind public.media_kind not null,
  title text not null check (length(title) between 1 and 200),
  year smallint check (year is null or year between 1800 and 2200),
  primary_creator text check (primary_creator is null or length(primary_creator) <= 120),
  cover_url text,
  external_id text,
  external_source text,
  created_at timestamptz not null default now()
);
create unique index media_external_unique
  on public.media (external_source, external_id)
  where external_source is not null and external_id is not null;
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  action public.post_action not null,
  rating numeric(2,1),
  caption text,
  created_at timestamptz not null default now(),
  constraint posts_one_per_author_media unique (author_id, media_id)
);
create table public.rate_limits (
  key text not null,
  ts timestamptz not null default now()
);

alter table public.media enable row level security;
alter table public.posts enable row level security;
create policy media_select_all on public.media for select using (true);
create policy media_insert_authenticated on public.media for insert to authenticated with check (true);
create policy posts_select_all on public.posts for select using (true);
create policy posts_insert_own on public.posts for insert with check (auth.uid() = author_id);

grant usage on schema public, auth to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- --- Run the REAL migrations -------------------------------------------------
\echo '>>> applying migration 20260816122000_rl_check_rejects_forged_keys.sql'
\i /mig.sql
\echo '>>> applying migration 20260804180000_post_rate_limit.sql'
\i /mig2.sql
\echo '>>> applying migration 20261117090000_import_library.sql'
\i /mig3.sql
\echo '>>> migrations applied OK'

insert into public.profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001','ada'),
  ('00000000-0000-0000-0000-000000000002','grace');

-- A batch of 50 rated films — more than the 30/minute per-post limit.
create table public.batch as
select jsonb_agg(jsonb_build_object(
         'kind', 'movie',
         'title', 'Film ' || n,
         'year', 1990 + n,
         'external_source', 'tmdb',
         'external_id', n::text,
         'action', 'rated',
         'rating', 5,
         'consumed_at', '2020-01-01T00:00:00Z'
       )) as items
  from generate_series(1, 50) as n;
grant select on public.batch to authenticated;

-- --- Tests -------------------------------------------------------------------

-- T1: must be security invoker, so posts' and media's RLS still apply.
do $$
declare is_definer boolean;
begin
  select p.prosecdef into is_definer
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'import_library';
  if is_definer is null then raise exception 'FAIL T1: import_library missing'; end if;
  if is_definer then raise exception 'FAIL T1: import_library is SECURITY DEFINER'; end if;
  raise notice 'PASS T1: import_library is security invoker';
end $$;

-- T2: a 50-item batch goes through in one call, past the per-post limit,
-- backdated to the export's date.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare result jsonb;
begin
  select public.import_library(items) into result from public.batch;
  if (result ->> 'imported')::int <> 50 or (result ->> 'skipped')::int <> 0 then
    raise exception 'FAIL T2: expected 50 imported, 0 skipped, got %', result;
  end if;
  if exists (select 1 from public.posts where created_at <> '2020-01-01T00:00:00Z') then
    raise exception 'FAIL T2: imported posts were not backdated';
  end if;
  raise notice 'PASS T2: 50 items imported in one call, backdated';
end $$;
commit;

-- T3: re-running the same import adds nothing.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare result jsonb;
begin
  select public.import_library(items) into result from public.batch;
  if (result ->> 'imported')::int <> 0 or (result ->> 'skipped')::int <> 50 then
    raise exception 'FAIL T3: re-run was not a no-op: %', result;
  end if;
  if (select count(*) from public.posts) <> 50 or (select count(*) from public.media) <> 50 then
    raise exception 'FAIL T3: re-run created duplicate rows';
  end if;
  raise notice 'PASS T3: re-running an import adds no duplicates';
end $$;
commit;

-- T4: an import never overwrites what the person already has in venn.
update public.posts set rating = 1, caption = 'changed my mind'
 where media_id = (select id from public.media where external_id = '1');
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
begin
  perform public.import_library(items) from public.batch;
  if not exists (
    select 1 from public.posts p join public.media m on m.id = p.media_id
     where m.external_id = '1' and p.rating = 1 and p.caption = 'changed my mind'
  ) then
    raise exception 'FAIL T4: import overwrote an existing post';
  end if;
  raise notice 'PASS T4: existing posts are left alone';
end $$;
commit;

-- T5: the bypass lives only as long as the setting does. import_library sets
-- it transaction-locally, so it is gone when that request ends; with it gone,
-- direct inserts meet the per-post limit again.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000002';
do $$
declare refused boolean := false;
begin
  perform public.import_library(items) from public.batch;
  if current_setting('venn.bulk_import_author', true) <> '00000000-0000-0000-0000-000000000002' then
    raise exception 'FAIL T5: setup — bypass setting not visible';
  end if;
  -- Spend grace's allowance with direct inserts on fresh media.
  begin
    for i in 1..31 loop
      perform set_config('venn.bulk_import_author', '', true);
      insert into public.media (kind, title, external_source, external_id)
        values ('book', 'Book ' || i, 'openlibrary', 'OL' || i);
      insert into public.posts (author_id, media_id, action)
        select '00000000-0000-0000-0000-000000000002', id, 'logged'
          from public.media where external_id = 'OL' || i;
    end loop;
  exception when sqlstate 'P0429' then refused := true;
  end;
  if not refused then
    raise exception 'FAIL T5: direct inserts escaped the per-post limit';
  end if;
  raise notice 'PASS T5: the per-post limit still applies outside import_library';
end $$;
rollback;

-- T6: the bypass names one author. Setting it for yourself does not cover
-- rows written as someone else (RLS would refuse those anyway; this checks
-- the trigger does not rely on that alone).
do $$
declare refused boolean := false;
begin
  perform set_config('venn.bulk_import_author', '00000000-0000-0000-0000-000000000002', true);
  delete from public.rate_limits;
  begin
    for i in 1..31 loop
      insert into public.media (kind, title, external_source, external_id)
        values ('album', 'Album ' || i, 'musicbrainz', 'mb' || i);
      insert into public.posts (author_id, media_id, action)
        select '00000000-0000-0000-0000-000000000001', id, 'logged'
          from public.media where external_id = 'mb' || i;
    end loop;
  exception when sqlstate 'P0429' then refused := true;
  end;
  if not refused then
    raise exception 'FAIL T6: one author''s bypass covered another author''s rows';
  end if;
  raise notice 'PASS T6: the bypass only covers the caller''s own rows';
end $$;

-- T7: bad input is refused — oversize batch, mismatched rating, no catalog id,
-- and no session.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare refused int := 0;
begin
  begin
    perform public.import_library((
      select jsonb_agg(jsonb_build_object('kind','movie','title','x','external_source','tmdb',
                                          'external_id', n::text,'action','logged'))
        from generate_series(1, 201) n));
  exception when sqlstate '22023' then refused := refused + 1;
  end;
  begin
    perform public.import_library('[{"kind":"movie","title":"x","external_source":"tmdb","external_id":"900","action":"logged","rating":5}]');
  exception when sqlstate '22023' then refused := refused + 1;
  end;
  begin
    perform public.import_library('[{"kind":"movie","title":"x","external_source":"tmdb","external_id":"901","action":"rated","rating":4}]');
  exception when sqlstate '22023' then refused := refused + 1;
  end;
  begin
    perform public.import_library('[{"kind":"movie","title":"x","external_source":"letterboxd","external_id":"902","action":"logged"}]');
  exception when sqlstate '22023' then refused := refused + 1;
  end;
  if refused <> 4 then
    raise exception 'FAIL T7: % of 4 malformed batches were refused', refused;
  end if;
  raise notice 'PASS T7: malformed batches are refused';
end $$;
commit;

begin; set local role authenticated; set local test.uid='';
do $$
begin
  begin
    perform public.import_library('[{"kind":"movie","title":"x","external_source":"tmdb","external_id":"903","action":"logged"}]');
    raise exception 'FAIL T8: a signed-out caller could import';
  exception when sqlstate '42501' then
    raise notice 'PASS T8: a signed-out caller is refused';
  end;
end $$;
commit;

-- T9: dates in the future are clamped to now, so an import cannot pin a post
-- to the top of every feed.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
begin
  perform public.import_library('[{"kind":"movie","title":"Future","external_source":"tmdb","external_id":"999","action":"logged","consumed_at":"2999-01-01T00:00:00Z"}]');
  if exists (
    select 1 from public.posts p join public.media m on m.id = p.media_id
     where m.external_id = '999' and p.created_at > now()
  ) then
    raise exception 'FAIL T9: a future date was kept';
  end if;
  raise notice 'PASS T9: future dates are clamped to now';
end $$;
commit;

-- T10: the batch allowance itself is rate-limited.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$
declare refused boolean := false;
begin
  begin
    for i in 1..31 loop
      perform public.import_library(items) from public.batch;
    end loop;
  exception when sqlstate 'P0429' then refused := true;
  end;
  if not refused then
    raise exception 'FAIL T10: import_library was not rate-limited';
  end if;
  raise notice 'PASS T10: import_library is rate-limited per caller';
end $$;
rollback;

\echo '>>> all import_library tests passed'
