-- =============================================================================
-- comment_policies_rls_test.sql — who may change a comment, and how deep
-- replies go.
--
-- Both guarantees live entirely in the database. Editing is scoped by policy
-- and pinned by a trigger; reply depth is a trigger alone. The clients mirror
-- both, but a mirror is not an enforcement — an insert from anywhere else,
-- including a future screen or a script, has to be refused here or not at all.
--
-- Same shape as the harnesses beside it: no Supabase stack, no pgTAP, a plain
-- postgres image, base schema built by hand, the REAL migrations applied with
-- \i, and RAISE EXCEPTION for failures.
--
-- Takes four migrations, in order, because each builds on the last:
--   /mig.sql   post_comments
--   /mig2.sql  notifications  (the notify trigger and the target constraint)
--   /mig3.sql  editable comments
--   /mig4.sql  replies
--   /mig5.sql  the reply notification target fix
--
-- The notifications migration is applied rather than stubbed on purpose. It
-- carries the trigger that fires on a new comment AND the constraint that
-- decides which target columns each kind may have — and it was that
-- constraint, unwidened, that would have made every reply notification fail
-- silently. Stubbing it would have removed the only thing T9 is for.
--
-- The widening ships as its own migration because migrations are append-only,
-- and leaving it out is what T9 caught on the first run that got this far: the
-- replies migration alone reproduces the bug exactly, notifying nobody with
-- nothing in the logs.
-- =============================================================================

\set ON_ERROR_STOP on

-- --- Emulate Supabase auth ----------------------------------------------------
create schema if not exists auth;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('test.uid', true), '')::uuid
$$;

do $$ begin create role anon; exception when duplicate_object then null; end $$;
do $$ begin create role authenticated; exception when duplicate_object then null; end $$;

-- --- Base schema --------------------------------------------------------------
create type public.media_kind as enum ('movie','show','book','album');
create type public.post_action as enum ('logged','rated','saved');

create table public.profiles (
  id uuid primary key,
  username text unique not null,
  created_at timestamptz not null default now()
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
  created_at timestamptz not null default now()
);
-- Same again for follows: the migration attaches a follow-notification
-- trigger, and its status column is what tells an accepted follow from a
-- pending request.
create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  status text not null default 'accepted',
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id)
);

-- The notifications migration attaches a like-notification trigger here, so
-- the table has to exist even though these tests never touch likes.
create table public.post_likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table public.rate_limits (key text not null, ts timestamptz not null default now());

alter table public.profiles enable row level security;
alter table public.media    enable row level security;
alter table public.posts    enable row level security;
alter table public.follows enable row level security;
alter table public.post_likes enable row level security;
alter table public.rate_limits enable row level security;

create policy profiles_select_all on public.profiles for select using (true);
create policy media_select_all    on public.media    for select using (true);
create policy posts_select_all    on public.posts    for select using (true);

grant usage on schema public, auth to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;

-- rl_check, with the caller-scoping guard the real one now has.
create or replace function public.rl_check(_key text, _limit int, _window interval)
returns boolean language plpgsql security definer set search_path = '' as $$
declare _count int; _caller uuid := auth.uid();
begin
  if _caller is not null and _key not like ('%:' || _caller::text) then
    return false;
  end if;
  insert into public.rate_limits (key, ts) values (_key, now());
  select count(*) into _count from public.rate_limits where key = _key and ts > now() - _window;
  return _count <= _limit;
end; $$;

-- --- Run the REAL migrations, in order ----------------------------------------
\echo '>>> applying 20260805100100_post_comments.sql'
\i /mig.sql
\echo '>>> applying 20260805200000_notifications.sql'
\i /mig2.sql
\echo '>>> applying 20260815100000_editable_comments.sql'
\i /mig3.sql
\echo '>>> applying 20260816100000_comment_replies.sql'
\i /mig4.sql
\echo '>>> applying 20260816101000_reply_notification_target.sql'
\i /mig5.sql
\echo '>>> migrations applied OK'

-- GRANT ON ALL TABLES only covers what exists at the time, and post_comments
-- is created by the migration above — so the grant before it missed the one
-- table these tests are about. The harnesses beside this one get away with a
-- single grant because their migrations only alter existing tables.
grant select, insert, update, delete on all tables in schema public to authenticated;

-- --- Seed ---------------------------------------------------------------------
insert into public.profiles (id, username) values
  ('00000000-0000-0000-0000-000000000001','poster'),
  ('00000000-0000-0000-0000-000000000002','commenter'),
  ('00000000-0000-0000-0000-000000000003','stranger');
insert into public.media (id, kind, title) values
  ('aaaaaaaa-0000-0000-0000-0000000000a1','movie','Dune');
insert into public.posts (id, author_id, media_id, action) values
  ('bbbbbbbb-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0000-0000000000a1','logged'),
  ('bbbbbbbb-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-000000000001',
   'aaaaaaaa-0000-0000-0000-0000000000a1','rated');
insert into public.post_comments (id, post_id, author_id, body) values
  ('cccccccc-0000-0000-0000-0000000000c1','bbbbbbbb-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-000000000002','original text');

-- --- Editing ------------------------------------------------------------------

-- T1: the author may edit their own comment, and the marker appears.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000002';
do $$ begin
  update public.post_comments set body = 'corrected text'
   where id = 'cccccccc-0000-0000-0000-0000000000c1';
  if not exists (
    select 1 from public.post_comments
     where id = 'cccccccc-0000-0000-0000-0000000000c1'
       and body = 'corrected text' and edited_at is not null
  ) then raise exception 'FAIL T1: author could not edit, or no marker'; end if;
  raise notice 'PASS T1: author edits and the edit is marked';
end $$; rollback;

-- T2: the POST's author may not rewrite someone else's comment. Deleting one
-- from your own post is moderation; rewriting it is impersonation.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000001';
do $$ declare changed int; begin
  update public.post_comments set body = 'words I did not write'
   where id = 'cccccccc-0000-0000-0000-0000000000c1';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'FAIL T2: post author rewrote a comment'; end if;
  raise notice 'PASS T2: post author cannot rewrite a comment';
end $$; rollback;

-- T3: a stranger may not edit at all.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ declare changed int; begin
  update public.post_comments set body = 'hello'
   where id = 'cccccccc-0000-0000-0000-0000000000c1';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'FAIL T3: a stranger edited a comment'; end if;
  raise notice 'PASS T3: a stranger cannot edit';
end $$; rollback;

-- T4: an update cannot move a comment to another post or another name.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000002';
do $$ declare moved_post uuid; moved_author uuid; begin
  update public.post_comments
     set post_id = 'bbbbbbbb-0000-0000-0000-0000000000b2',
         author_id = '00000000-0000-0000-0000-000000000003',
         body = 'still mine'
   where id = 'cccccccc-0000-0000-0000-0000000000c1';
  select post_id, author_id into moved_post, moved_author
    from public.post_comments where id = 'cccccccc-0000-0000-0000-0000000000c1';
  if moved_post <> 'bbbbbbbb-0000-0000-0000-0000000000b1'
    then raise exception 'FAIL T4: comment moved to another post'; end if;
  if moved_author <> '00000000-0000-0000-0000-000000000002'
    then raise exception 'FAIL T4: comment changed author'; end if;
  raise notice 'PASS T4: post and author are pinned across an update';
end $$; rollback;

-- T5: the marker is not stamped when the body did not change. Otherwise any
-- write would brand a comment as edited, and the marker would mean nothing.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000002';
do $$ begin
  update public.post_comments set body = 'original text'
   where id = 'cccccccc-0000-0000-0000-0000000000c1';
  if exists (
    select 1 from public.post_comments
     where id = 'cccccccc-0000-0000-0000-0000000000c1' and edited_at is not null
  ) then raise exception 'FAIL T5: unchanged body was marked as edited'; end if;
  raise notice 'PASS T5: an unchanged body is not marked as edited';
end $$; rollback;

-- --- Replies --------------------------------------------------------------------

-- T6: a reply to a root comment is allowed.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  insert into public.post_comments (post_id, author_id, body, parent_id)
  values ('bbbbbbbb-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000003',
          'a reply','cccccccc-0000-0000-0000-0000000000c1');
  raise notice 'PASS T6: a reply to a root comment is allowed';
end $$; rollback;

-- T7: a reply to a reply is refused. This is the cap the clients mirror but
-- do not enforce.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ declare reply_id uuid; begin
  insert into public.post_comments (post_id, author_id, body, parent_id)
  values ('bbbbbbbb-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000003',
          'a reply','cccccccc-0000-0000-0000-0000000000c1')
  returning id into reply_id;

  begin
    insert into public.post_comments (post_id, author_id, body, parent_id)
    values ('bbbbbbbb-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000003',
            'a reply to a reply', reply_id);
    raise exception 'FAIL T7: a second-level reply was accepted';
  exception when raise_exception then
    if sqlerrm like 'FAIL T7%' then raise; end if;
    raise notice 'PASS T7: a reply to a reply is refused';
  end;
end $$; rollback;

-- T8: a reply must live on the same post as its parent, or it appears under
-- neither thread correctly.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  begin
    insert into public.post_comments (post_id, author_id, body, parent_id)
    values ('bbbbbbbb-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-000000000003',
            'wrong post','cccccccc-0000-0000-0000-0000000000c1');
    raise exception 'FAIL T8: a cross-post reply was accepted';
  exception when raise_exception then
    if sqlerrm like 'FAIL T8%' then raise; end if;
    raise notice 'PASS T8: a reply cannot live on a different post than its parent';
  end;
end $$; rollback;

-- T9: replying notifies the parent's author with `reply`, not `comment`.
-- The target constraint refuses a reply carrying both ids unless it was
-- widened, and the notify trigger swallows exceptions — so a regression here
-- is silent, and this is the only thing that would catch it.
begin; set local role authenticated; set local test.uid='00000000-0000-0000-0000-000000000003';
do $$ begin
  insert into public.post_comments (post_id, author_id, body, parent_id)
  values ('bbbbbbbb-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000003',
          'answering you','cccccccc-0000-0000-0000-0000000000c1');
end $$;

-- Read as the recipient. notifications_select_own scopes rows to
-- auth.uid() = recipient_id, so the replier cannot see what they caused —
-- which is correct, and is why the first version of this test could not
-- tell a missing notification from an invisible one.
set local test.uid='00000000-0000-0000-0000-000000000002';
do $$ declare kinds text[]; begin
  select array_agg(kind) into kinds
    from public.notifications
   where recipient_id = '00000000-0000-0000-0000-000000000002';

  if kinds is null then raise exception 'FAIL T9: reply notified nobody'; end if;
  if not ('reply' = any(kinds)) then
    raise exception 'FAIL T9: expected a reply notification, got %', kinds;
  end if;
  raise notice 'PASS T9: a reply notifies the parent author as a reply';
end $$; rollback;

\echo '>>> ALL TESTS PASSED'
