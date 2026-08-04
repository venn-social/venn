-- =============================================================================
-- 20260804180000_post_rate_limit.sql — cap how fast one author can post.
-- =============================================================================
-- `posts_insert_own` (20260425120000_init.sql) proves *ownership* — that the
-- author_id is the caller — but says nothing about *frequency*. Nothing stops
-- a script inserting thousands of rows as itself.
--
-- This is a trigger rather than a create_post RPC on purpose: a trigger covers
-- every insert path, so the iOS app (which inserts into posts directly) is
-- protected immediately, with no Swift change and no App Store release. An RPC
-- would only protect callers that remember to use it.
--
-- 30/minute per author is far above any human logging session — even bulk
-- entry after a binge — while stopping a runaway loop.
--
-- Raises P0429, which AppError.from(_:) already maps to AppError.rateLimited
-- on iOS, and which lib/compose.ts maps to user-facing copy on web.
--
-- Idempotent: safe to replay.
-- =============================================================================

create or replace function public.enforce_post_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.rl_check('create_post:' || new.author_id::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  return new;
end;
$$;

drop trigger if exists posts_rate_limit on public.posts;
create trigger posts_rate_limit
  before insert on public.posts
  for each row
  execute function public.enforce_post_rate_limit();
