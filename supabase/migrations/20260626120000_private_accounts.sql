-- =============================================================================
-- 20260626120000_private_accounts.sql — private accounts + follow requests.
-- =============================================================================
-- Adds an Instagram-style private-account option. A private user's consumption
-- content (posts → feed + profile shelves, and the Venn overlap) is visible
-- only to ACCEPTED followers; following a private user becomes a PENDING
-- request the user approves. Public accounts are unchanged.
--
-- ⚠️  UNVERIFIED at authoring time: there was no container runtime available to
--     run `npm run db:reset`, so this migration has NOT been applied/tested
--     locally. Before merge + `db:push`, apply it and exercise the RLS (see
--     docs/specs/private-accounts.md "Verification"). Then `make codegen`.
--
-- ⚠️  CLIENT DEPENDENCY — DO NOT `db:push` THIS ALONE. It drops
--     `follows_insert_own`, so the current app's direct-insert follow stops
--     working until the Swift client is switched to the `request_follow` RPC.
--     Push this together with (or after) the client PR, never before.
--
-- Idempotent: safe to replay (IF NOT EXISTS / DROP POLICY IF EXISTS / CREATE
-- OR REPLACE).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Schema: privacy flag + follow request status.
-- -----------------------------------------------------------------------------
alter table public.profiles
  add column if not exists is_private boolean not null default false;

-- Existing follows grandfather to 'accepted' via the column default, so flipping
-- this feature on never retroactively locks out current followers.
alter table public.follows
  add column if not exists status text not null default 'accepted';

alter table public.follows
  drop constraint if exists follows_status_valid,
  add constraint follows_status_valid check (status in ('pending', 'accepted'));

create index if not exists follows_followee_status_idx
  on public.follows (followee_id, status);

-- -----------------------------------------------------------------------------
-- posts RLS — gate private authors' posts to accepted followers (+ the author).
-- This one policy covers the feed AND the profile shelves (both read `posts`),
-- and compute_overlap (SECURITY INVOKER) inherits it automatically.
-- -----------------------------------------------------------------------------
drop policy if exists posts_select_all on public.posts;
drop policy if exists posts_select_visible on public.posts;
create policy posts_select_visible on public.posts for select
  using (
    auth.uid() = author_id
    or exists (
      select 1 from public.profiles pr
      where pr.id = posts.author_id and pr.is_private = false
    )
    or exists (
      select 1 from public.follows f
      where f.followee_id = posts.author_id
        and f.follower_id = auth.uid()
        and f.status = 'accepted'
    )
  );

-- -----------------------------------------------------------------------------
-- follows RLS — reads.
-- Direct INSERT is removed: all follow creation goes through request_follow()
-- so a client can't self-insert an 'accepted' edge and bypass privacy.
-- SELECT is tightened so private-account edges and all pending edges stay
-- private; header counts come from follow_counts() (security definer) instead.
-- DELETE (unfollow / cancel request) stays owner-only.
-- -----------------------------------------------------------------------------
drop policy if exists follows_insert_own on public.follows;

drop policy if exists follows_select_all on public.follows;
drop policy if exists follows_select_visible on public.follows;
create policy follows_select_visible on public.follows for select
  using (
    auth.uid() = follower_id
    or auth.uid() = followee_id
    or (
      follows.status = 'accepted'
      and exists (
        select 1 from public.profiles pr
        where pr.id = follows.followee_id and pr.is_private = false
      )
      and exists (
        select 1 from public.profiles pr
        where pr.id = follows.follower_id and pr.is_private = false
      )
    )
  );

-- -----------------------------------------------------------------------------
-- request_follow(target) — the only path to create a follow edge.
-- Returns the resulting status: 'accepted' (public target) or 'pending'
-- (private target). Rate-limited 60/min per follower.
-- -----------------------------------------------------------------------------
create or replace function public.request_follow(target uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  follower uuid := auth.uid();
  target_private boolean;
  new_status text;
begin
  if follower is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  if follower = target then
    raise exception 'cannot follow self' using errcode = '22023';
  end if;
  if not public.rl_check('request_follow:' || follower::text, 60, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;

  select is_private into target_private from public.profiles where id = target;
  if target_private is null then
    raise exception 'no such user' using errcode = 'P0002';
  end if;

  new_status := case when target_private then 'pending' else 'accepted' end;

  insert into public.follows (follower_id, followee_id, status)
    values (follower, target, new_status)
    on conflict (follower_id, followee_id) do nothing;

  -- Return the actually-stored status (an existing edge may differ).
  select status into new_status
    from public.follows
   where follower_id = follower and followee_id = target;
  return new_status;
end;
$$;

revoke execute on function public.request_follow(uuid) from public, anon;
grant execute on function public.request_follow(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- respond_to_follow_request(requester, accept) — only the followee may accept
-- (→ 'accepted') or reject (delete the pending row). Rate-limited 60/min.
-- -----------------------------------------------------------------------------
create or replace function public.respond_to_follow_request(requester uuid, accept boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := auth.uid();
begin
  if me is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  if not public.rl_check('respond_follow:' || me::text, 60, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;

  if accept then
    update public.follows set status = 'accepted'
     where follower_id = requester and followee_id = me and status = 'pending';
  else
    delete from public.follows
     where follower_id = requester and followee_id = me and status = 'pending';
  end if;
end;
$$;

revoke execute on function public.respond_to_follow_request(uuid, boolean) from public, anon;
grant execute on function public.respond_to_follow_request(uuid, boolean) to authenticated;

-- -----------------------------------------------------------------------------
-- follow_counts(target) — accepted-only follower/following counts, safe to call
-- for any profile so the header counts survive the tightened follows SELECT.
-- -----------------------------------------------------------------------------
create or replace function public.follow_counts(target uuid)
returns table (followers bigint, following bigint)
language sql
security definer
set search_path = ''
as $$
  select
    (select count(*) from public.follows
       where followee_id = target and status = 'accepted'),
    (select count(*) from public.follows
       where follower_id = target and status = 'accepted');
$$;

revoke execute on function public.follow_counts(uuid) from public, anon;
grant execute on function public.follow_counts(uuid) to authenticated;
