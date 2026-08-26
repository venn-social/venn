-- =============================================================================
-- hall_of_fame_test.sql — the twelve-item cap, and the rules around it.
--
-- The cap is not written anywhere as a number a client checks. It falls out
-- of a range check and a unique index, which is the point: two clients both
-- seeing eleven items cannot both add a twelfth. That property is worth a
-- test, because it is invisible in the code that relies on it.
--
-- Same shape as the other harnesses here: no Supabase stack and no pgTAP,
-- just a plain postgres image, a hand-built base schema, the REAL migration
-- applied with \i, and RAISE EXCEPTION for failures.
--
-- Run locally (needs any Docker-compatible runtime):
--   docker run -d --name halltest -e POSTGRES_PASSWORD=postgres \
--     -v "$PWD/supabase/migrations/20260826120000_hall_of_fame.sql":/mig.sql:ro \
--     -v "$PWD/supabase/tests/hall_of_fame_test.sql":/harness.sql:ro \
--     postgres:17-alpine
--   until docker exec halltest pg_isready -U postgres; do sleep 1; done
--   docker exec halltest psql -U postgres -v ON_ERROR_STOP=1 -f /harness.sql
--   docker rm -f halltest
-- =============================================================================

\set ON_ERROR_STOP on

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
  title text not null
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

-- --- Run the REAL migration --------------------------------------------------
-- reorder_hall filters on auth.uid(), so the harness needs Supabase's.
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid
$$;

\echo '>>> applying migration 20260826120000_hall_of_fame.sql'
\i /mig.sql
\echo '>>> applying migration 20260827120000_reorder_hall.sql'
\i /mig2.sql
\echo '>>> migrations applied OK'

-- --- Seed --------------------------------------------------------------------
insert into public.profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001','ada'),
  ('00000000-0000-0000-0000-000000000002','grace');

insert into public.media (id, kind, title)
select ('aaaaaaaa-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid, 'movie', 'Film ' || n
  from generate_series(1, 20) as n;

-- Ada has logged twenty films; none are in her hall yet.
insert into public.posts (author_id, media_id, action)
select '00000000-0000-0000-0000-000000000001', id, 'logged' from public.media;

-- --- Tests -------------------------------------------------------------------

-- T1: a logged post can take a place in the hall.
do $$
begin
  update public.posts set hall_position = 1
   where author_id = '00000000-0000-0000-0000-000000000001'
     and media_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  if not exists (select 1 from public.posts where hall_position = 1) then
    raise exception 'FAIL T1: a logged post could not be put in the hall';
  end if;
  raise notice 'PASS T1: a logged post can enter the hall';
end $$;

-- T2: positions outside 1..12 are refused. This is half of the cap.
do $$
declare rejected int := 0;
begin
  begin
    update public.posts set hall_position = 13
     where media_id = 'aaaaaaaa-0000-0000-0000-000000000002';
  exception when check_violation then rejected := rejected + 1;
  end;
  begin
    update public.posts set hall_position = 0
     where media_id = 'aaaaaaaa-0000-0000-0000-000000000002';
  exception when check_violation then rejected := rejected + 1;
  end;
  if rejected <> 2 then
    raise exception 'FAIL T2: out-of-range positions were accepted (% of 2 refused)', rejected;
  end if;
  raise notice 'PASS T2: only positions 1-12 are allowed';
end $$;

-- T3: one person cannot put two things in the same slot. The other half.
do $$
begin
  begin
    update public.posts set hall_position = 1
     where media_id = 'aaaaaaaa-0000-0000-0000-000000000003';
    raise exception 'FAIL T3: two items shared a slot';
  exception when unique_violation then
    raise notice 'PASS T3: a slot holds one item';
  end;
end $$;

-- T4: the cap itself. Twelve slots, all taken, and a thirteenth cannot get
-- in by any position — which is the property no client-side count gives you.
do $$
declare blocked boolean := true;
begin
  for i in 2..12 loop
    update public.posts set hall_position = i
     where media_id = ('aaaaaaaa-0000-0000-0000-' || lpad((i + 1)::text, 12, '0'))::uuid;
  end loop;

  for i in 1..12 loop
    begin
      update public.posts set hall_position = i
       where media_id = 'aaaaaaaa-0000-0000-0000-000000000020';
      blocked := false;
    exception when unique_violation then null;
    end;
  end loop;

  if not blocked then
    raise exception 'FAIL T4: a thirteenth item got into the hall';
  end if;
  if (select count(*) from public.posts where hall_position is not null) <> 12 then
    raise exception 'FAIL T4: the hall does not hold exactly twelve';
  end if;
  raise notice 'PASS T4: the hall caps at twelve, with no count anywhere';
end $$;

-- T5: two people may each use slot 1. The cap is per person, not global.
do $$
begin
  insert into public.posts (author_id, media_id, action, hall_position)
  values ('00000000-0000-0000-0000-000000000002',
          'aaaaaaaa-0000-0000-0000-000000000001', 'logged', 1);
  raise notice 'PASS T5: the cap is per person';
end $$;

-- T6: a watchlist entry cannot be in the hall. You cannot have loved
-- something you have not got to yet.
do $$
begin
  begin
    insert into public.posts (author_id, media_id, action, hall_position)
    values ('00000000-0000-0000-0000-000000000002',
            'aaaaaaaa-0000-0000-0000-000000000002', 'saved', 2);
    raise exception 'FAIL T6: a watchlist entry entered the hall';
  exception when check_violation then
    raise notice 'PASS T6: watchlist entries stay out of the hall';
  end;
end $$;

-- T7: leaving the hall is always allowed, whatever else is true.
do $$
begin
  update public.posts set hall_position = null
   where author_id = '00000000-0000-0000-0000-000000000001';
  if exists (select 1 from public.posts
              where author_id = '00000000-0000-0000-0000-000000000001'
                and hall_position is not null) then
    raise exception 'FAIL T7: could not empty the hall';
  end if;
  raise notice 'PASS T7: anything can leave the hall';
end $$;

-- T8: reordering survives a swap. A single UPDATE cannot do this — the
-- unique index rejects the moment two rows both hold position 1 — which is
-- the whole reason reorder_hall clears before it writes.
do $$
declare ids uuid[];
begin
  perform set_config('test.uid', '00000000-0000-0000-0000-000000000001', false);
  update public.posts set hall_position = null where author_id = '00000000-0000-0000-0000-000000000001';
  update public.posts set hall_position = 1
   where author_id = '00000000-0000-0000-0000-000000000001'
     and media_id = 'aaaaaaaa-0000-0000-0000-000000000001';
  update public.posts set hall_position = 2
   where author_id = '00000000-0000-0000-0000-000000000001'
     and media_id = 'aaaaaaaa-0000-0000-0000-000000000002';

  select array_agg(id order by hall_position desc) into ids
    from public.posts
   where author_id = '00000000-0000-0000-0000-000000000001'
     and hall_position is not null;

  perform public.reorder_hall(ids);

  if (select hall_position from public.posts
       where author_id = '00000000-0000-0000-0000-000000000001'
         and media_id = 'aaaaaaaa-0000-0000-0000-000000000002') <> 1 then
    raise exception 'FAIL T8: the swap did not take';
  end if;
  raise notice 'PASS T8: two items can swap places';
end $$;

-- T9: reordering cannot reach into someone else's hall. Run as ada,
-- handing it grace's post ids — the author_id filter is what is under
-- test, since RLS is not enabled in this harness.
do $$
declare before smallint;
begin
  -- Still ada, deliberately: this reorders grace's ids as ada.
  perform set_config('test.uid', '00000000-0000-0000-0000-000000000001', false);
  select hall_position into before from public.posts
   where author_id = '00000000-0000-0000-0000-000000000002' and hall_position is not null
   limit 1;

  perform public.reorder_hall(array(
    select id from public.posts where author_id = '00000000-0000-0000-0000-000000000002'
  ));

  if (select hall_position from public.posts
       where author_id = '00000000-0000-0000-0000-000000000002' and hall_position is not null
       limit 1) is distinct from before then
    raise exception 'FAIL T9: another account''s hall was reordered';
  end if;
  raise notice 'PASS T9: only your own hall reorders';
end $$;

\echo 'ALL TESTS PASSED'

