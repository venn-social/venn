-- =============================================================================
-- 20260805100000_post_likes.sql — likes on posts.
-- =============================================================================
-- The social signal venn had none of. Every comparable product (Letterboxd,
-- Cosmos, Instagram) has one, and beyond the social value it's the first
-- thing that records *preference* rather than *consumption*: today the only
-- signal is that you logged something, not that you rated anyone else's
-- take highly. Rule-based recommendations will need exactly this.
--
-- Shape: (post_id, user_id) composite primary key. A like is a fact that
-- either exists or doesn't — no id column, no updates, and the PK gives
-- idempotency for free (like twice = one row, via ON CONFLICT DO NOTHING).
--
-- Reads are public, matching posts_select_all: like counts are visible to
-- anyone who can see the post. Writes are your own only. Rate-limited by
-- trigger for the same reason posts are (20260804180000) — RLS proves
-- ownership, not frequency.
--
-- Idempotent: safe to replay.
-- =============================================================================

create table if not exists public.post_likes (
  post_id uuid not null references public.posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

-- Counting likes for a post, and listing what one user liked, are the two
-- access patterns. The PK covers the first; this covers the second.
create index if not exists post_likes_user_id_idx on public.post_likes (user_id, created_at desc);

alter table public.post_likes enable row level security;

-- Anyone who can see a post can see its likes. Matches posts_select_all —
-- a like count that varied by viewer would be worse than none.
drop policy if exists post_likes_select_all on public.post_likes;
create policy post_likes_select_all
  on public.post_likes for select
  using (true);

drop policy if exists post_likes_insert_own on public.post_likes;
create policy post_likes_insert_own
  on public.post_likes for insert
  with check (auth.uid() = user_id);

drop policy if exists post_likes_delete_own on public.post_likes;
create policy post_likes_delete_own
  on public.post_likes for delete
  using (auth.uid() = user_id);

-- No UPDATE policy on purpose: a like has nothing to change. Unliking is a
-- delete.

-- -----------------------------------------------------------------------------
-- Rate limit, same reasoning as posts_rate_limit: RLS proves the like is
-- yours, not that you aren't inserting thousands. 120/minute is far above
-- human tapping and still bounds a script.
-- -----------------------------------------------------------------------------
create or replace function public.enforce_like_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.rl_check('like_post:' || new.user_id::text, 120, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  return new;
end;
$$;

drop trigger if exists post_likes_rate_limit on public.post_likes;
create trigger post_likes_rate_limit
  before insert on public.post_likes
  for each row
  execute function public.enforce_like_rate_limit();

-- -----------------------------------------------------------------------------
-- post_like_info(post_ids) — like count and whether the caller liked it, for
-- many posts at once.
--
-- One call per feed page rather than one per row: a feed of 20 posts would
-- otherwise be 40 round trips. SECURITY INVOKER because it only reads rows
-- RLS already exposes.
-- -----------------------------------------------------------------------------
create or replace function public.post_like_info(post_ids uuid[])
returns table (
  post_id uuid,
  like_count bigint,
  liked_by_me boolean
)
language sql
security invoker
set search_path = ''
as $$
  select
    p.id as post_id,
    count(l.user_id) as like_count,
    bool_or(l.user_id = auth.uid()) is true as liked_by_me
  from unnest(post_ids) as p (id)
  left join public.post_likes l on l.post_id = p.id
  group by p.id;
$$;

revoke execute on function public.post_like_info(uuid[]) from public;
grant execute on function public.post_like_info(uuid[]) to anon, authenticated;
