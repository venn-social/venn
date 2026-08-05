-- =============================================================================
-- 20260805100100_post_comments.sql — comments on posts.
-- =============================================================================
-- What conversation on Letterboxd and Cosmos is built from. A post today is
-- a broadcast; this makes it a thread.
--
-- Deliberately flat, not threaded. Replies-to-replies need a parent_id, a
-- depth cap, and a recursive read — none of which is worth building before
-- anyone has commented once. A parent_id can be added later without
-- rewriting what's here.
--
-- Body is 1-500 chars, matching posts_caption_length and Sanitize.caption,
-- so the same validator serves both on the client.
--
-- Idempotent: safe to replay.
-- =============================================================================

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.post_comments
  drop constraint if exists post_comments_body_length,
  add constraint post_comments_body_length check (
    length(btrim(body)) between 1 and 500
  );

-- Reading a post's comments oldest-first is the only read pattern.
create index if not exists post_comments_post_id_idx
  on public.post_comments (post_id, created_at asc);

alter table public.post_comments enable row level security;

-- Visible to anyone who can see the post, matching posts_select_all.
drop policy if exists post_comments_select_all on public.post_comments;
create policy post_comments_select_all
  on public.post_comments for select
  using (true);

drop policy if exists post_comments_insert_own on public.post_comments;
create policy post_comments_insert_own
  on public.post_comments for insert
  with check (auth.uid() = author_id);

-- Deletable by the comment's author OR the post's author: on someone else's
-- post you can retract your own words, and on your own post you can remove
-- someone else's. That second half is the minimum viable moderation tool,
-- and without it the only recourse for an abusive comment is deleting your
-- own post.
drop policy if exists post_comments_delete_own_or_post_author on public.post_comments;
create policy post_comments_delete_own_or_post_author
  on public.post_comments for delete
  using (
    auth.uid() = author_id
    or auth.uid() = (select author_id from public.posts where id = post_id)
  );

-- No UPDATE policy: an edited comment in a thread someone already replied
-- to rewrites history. Delete and repost instead.

-- -----------------------------------------------------------------------------
-- Rate limit — 30/minute per author, matching posts.
-- -----------------------------------------------------------------------------
create or replace function public.enforce_comment_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.rl_check('comment_post:' || new.author_id::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  return new;
end;
$$;

drop trigger if exists post_comments_rate_limit on public.post_comments;
create trigger post_comments_rate_limit
  before insert on public.post_comments
  for each row
  execute function public.enforce_comment_rate_limit();

-- -----------------------------------------------------------------------------
-- post_comment_counts(post_ids) — comment counts for many posts at once,
-- for the same reason post_like_info batches: one call per feed page.
-- -----------------------------------------------------------------------------
create or replace function public.post_comment_counts(post_ids uuid[])
returns table (
  post_id uuid,
  comment_count bigint
)
language sql
security invoker
set search_path = ''
as $$
  select p.id as post_id, count(c.id) as comment_count
  from unnest(post_ids) as p (id)
  left join public.post_comments c on c.post_id = p.id
  group by p.id;
$$;

revoke execute on function public.post_comment_counts(uuid[]) from public;
grant execute on function public.post_comment_counts(uuid[]) to anon, authenticated;
