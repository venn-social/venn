-- =============================================================================
-- 20260805200000_notifications.sql — who did what to you.
-- =============================================================================
-- Likes, comments, follows, and follow requests exist, but nothing tells you
-- they happened: you find out by opening a post you already knew about. That
-- makes the social loop one-directional and is the single largest reason a
-- new user logs one thing and never returns.
--
-- Rows are written by triggers under `security definer`, never by the
-- client. A notification is a claim that something happened, and a claim the
-- client can forge is worthless — an INSERT policy would let anyone write
-- "@venn started following you" into your feed.
--
-- Four kinds, each tied to an event that already has a table:
--   like           someone liked your post
--   comment        someone commented on your post
--   follow         someone followed you (public account, or an accepted request)
--   follow_request someone asked to follow you (private account)
--
-- Idempotent: safe to replay.
-- =============================================================================

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  -- Who sees it.
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  -- Who caused it. Cascade-deletes with the actor: a notification about a
  -- deleted account is unreadable ("someone liked your post") and worse,
  -- unactionable.
  actor_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null,
  -- Set for like and comment; null for follow kinds. Cascades so deleting a
  -- post takes its notifications with it.
  post_id uuid references public.posts (id) on delete cascade,
  comment_id uuid references public.post_comments (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- Null until seen. A timestamp rather than a boolean so "unread since"
  -- and badge counts are the same query.
  read_at timestamptz
);

alter table public.notifications
  drop constraint if exists notifications_kind_valid,
  add constraint notifications_kind_valid check (
    kind in ('like', 'comment', 'follow', 'follow_request')
  );

-- Nobody needs telling about their own activity.
alter table public.notifications
  drop constraint if exists notifications_no_self_notify,
  add constraint notifications_no_self_notify check (recipient_id <> actor_id);

-- A like carries a post, a follow does not. Enforcing the shape here stops
-- a future trigger from writing a half-formed row that the client then has
-- to defend against.
alter table public.notifications
  drop constraint if exists notifications_target_matches_kind,
  add constraint notifications_target_matches_kind check (
    case kind
      when 'like' then post_id is not null and comment_id is null
      when 'comment' then post_id is not null and comment_id is not null
      else post_id is null and comment_id is null
    end
  );

-- The only read pattern: my notifications, newest first.
create index if not exists notifications_recipient_idx
  on public.notifications (recipient_id, created_at desc);

-- Badge counts read unread rows only, and for an active user that's a tiny
-- slice of the table. Partial index keeps it that way.
create index if not exists notifications_unread_idx
  on public.notifications (recipient_id)
  where read_at is null;

-- -----------------------------------------------------------------------------
-- Dedup
-- -----------------------------------------------------------------------------
-- Unlike-then-like is one tap away, and each cycle would otherwise append a
-- fresh "X liked your post". Likes and follows are *states*, so at most one
-- row can exist per (recipient, actor, kind, target).
--
-- Comments are deliberately excluded: two comments are two events, and
-- collapsing them would hide the second.
create unique index if not exists notifications_unique_like_idx
  on public.notifications (recipient_id, actor_id, post_id)
  where kind = 'like';

create unique index if not exists notifications_unique_follow_idx
  on public.notifications (recipient_id, actor_id, kind)
  where kind in ('follow', 'follow_request');

alter table public.notifications enable row level security;

-- Yours and only yours. The actor doesn't get to see whether you've read it.
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
  on public.notifications for select
  using (auth.uid() = recipient_id);

-- Marking as read is the only write a client may make. The USING clause
-- alone would let a row be updated *into* someone else's inbox, so the
-- WITH CHECK clause repeats the test on the new row.
drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
  on public.notifications for update
  using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own
  on public.notifications for delete
  using (auth.uid() = recipient_id);

-- No INSERT policy at all. Triggers below run as `security definer` and
-- bypass RLS; anything else must not be able to write here.

-- -----------------------------------------------------------------------------
-- notify(...) — one place that writes a row.
-- -----------------------------------------------------------------------------
-- Every trigger funnels through this so the self-notify check, the dedup
-- behaviour, and the "never fail the originating write" rule are stated
-- once rather than four times.
create or replace function public.create_notification(
  _recipient_id uuid,
  _actor_id uuid,
  _kind text,
  _post_id uuid default null,
  _comment_id uuid default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if _recipient_id is null or _recipient_id = _actor_id then
    return;
  end if;

  insert into public.notifications (
    recipient_id, actor_id, kind, post_id, comment_id
  )
  values (_recipient_id, _actor_id, _kind, _post_id, _comment_id)
  -- Re-liking something you already liked surfaces the existing row rather
  -- than erroring; the unique indexes above define what "already" means.
  on conflict do nothing;
end;
$$;

revoke execute on function public.create_notification(uuid, uuid, text, uuid, uuid) from public;

-- -----------------------------------------------------------------------------
-- Triggers
-- -----------------------------------------------------------------------------
-- Each is AFTER INSERT and returns null-safe: a notification failing must
-- never roll back the like, comment, or follow that caused it. Losing a
-- notification is a nuisance; losing the follow is a bug the user sees.

create or replace function public.notify_post_liked()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  author uuid;
begin
  select author_id into author from public.posts where id = new.post_id;
  perform public.create_notification(author, new.user_id, 'like', new.post_id, null);
  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists post_likes_notify on public.post_likes;
create trigger post_likes_notify
  after insert on public.post_likes
  for each row
  execute function public.notify_post_liked();

create or replace function public.notify_post_commented()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  author uuid;
begin
  select author_id into author from public.posts where id = new.post_id;
  perform public.create_notification(
    author, new.author_id, 'comment', new.post_id, new.id
  );
  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists post_comments_notify on public.post_comments;
create trigger post_comments_notify
  after insert on public.post_comments
  for each row
  execute function public.notify_post_commented();

-- A follow of a public account inserts with status 'accepted'; a request to
-- a private one inserts 'pending' and is updated to 'accepted' later. Both
-- paths need to notify, and they differ in what they say, so this fires on
-- insert and on the status change.
create or replace function public.notify_followed()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status = 'accepted' then
    -- The request notification, if there was one, has served its purpose.
    delete from public.notifications
    where recipient_id = new.followee_id
      and actor_id = new.follower_id
      and kind = 'follow_request';

    perform public.create_notification(
      new.followee_id, new.follower_id, 'follow', null, null
    );
  else
    perform public.create_notification(
      new.followee_id, new.follower_id, 'follow_request', null, null
    );
  end if;
  return new;
exception
  when others then
    return new;
end;
$$;

drop trigger if exists follows_notify on public.follows;
create trigger follows_notify
  after insert on public.follows
  for each row
  execute function public.notify_followed();

drop trigger if exists follows_accepted_notify on public.follows;
create trigger follows_accepted_notify
  after update of status on public.follows
  for each row
  when (old.status is distinct from new.status and new.status = 'accepted')
  execute function public.notify_followed();

-- -----------------------------------------------------------------------------
-- unread_notification_count() — the badge.
-- -----------------------------------------------------------------------------
-- Runs `security invoker` so RLS scopes it to the caller: there is no way to
-- ask this question about someone else.
create or replace function public.unread_notification_count()
returns bigint
language sql
security invoker
stable
set search_path = ''
as $$
  select count(*)
  from public.notifications
  where recipient_id = (select auth.uid())
    and read_at is null;
$$;

revoke execute on function public.unread_notification_count() from public;
grant execute on function public.unread_notification_count() to authenticated;

-- -----------------------------------------------------------------------------
-- mark_notifications_read() — opening the screen clears the badge.
-- -----------------------------------------------------------------------------
-- Marks everything unread rather than taking a list of ids: the screen shows
-- them all at once, so anything else would leave the badge lying. Returns the
-- number cleared so the client can skip a refetch when it's zero.
create or replace function public.mark_notifications_read()
returns bigint
language plpgsql
security invoker
set search_path = ''
as $$
declare
  cleared bigint;
begin
  update public.notifications
  set read_at = now()
  where recipient_id = (select auth.uid())
    and read_at is null;

  get diagnostics cleared = row_count;
  return cleared;
end;
$$;

revoke execute on function public.mark_notifications_read() from public;
grant execute on function public.mark_notifications_read() to authenticated;
