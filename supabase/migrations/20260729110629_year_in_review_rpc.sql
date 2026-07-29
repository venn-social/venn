-- =============================================================================
-- 20260729110629_year_in_review_rpc.sql — "Year in Review" personal stats RPCs.
-- =============================================================================
-- Two read-only aggregation RPCs powering a personal-stats screen on the
-- Profile tab. Both are always scoped to auth.uid() — there is no
-- target-user parameter, this is never "someone else's stats":
--
--   personal_stats_by_kind()  — per media_kind: how much the caller has
--     consumed (logged/rated — same "taste vs. intent" split documented in
--     compute_overlap; saved is a watchlist add, not consumption), how many
--     of those are saved vs. rated, the average rating, and the creator
--     (director/author/artist) they've consumed the most of that kind.
--
--   personal_stats_monthly() — trailing 12 calendar months (including
--     zero-post months, so the client can render a full 12-bar chart without
--     gaps) of consumed-post counts, for a monthly-activity chart.
--
-- Both are SECURITY INVOKER: they only ever read the caller's own rows via
-- auth.uid(), which posts/media already expose to their owner under RLS —
-- no elevated privilege is needed. Both rate-limit through the existing
-- rl_check helper (see 20260611230000_overlap_rpc.sql) and raise P0429
-- when exceeded, same as every other RPC.
--
-- Idempotent: safe to replay.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- personal_stats_by_kind — one row per media_kind the caller has any post
-- for. top_creator/top_creator_count are null when the caller has no
-- logged/rated posts of that kind (e.g. saved-only); ties are broken
-- arbitrarily (alphabetically) for determinism.
-- -----------------------------------------------------------------------------
create or replace function public.personal_stats_by_kind()
returns table (
  kind public.media_kind,
  consumed_count bigint,
  saved_count bigint,
  rated_count bigint,
  avg_rating numeric,
  top_creator text,
  top_creator_count bigint
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
begin
  if viewer is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  if not public.rl_check('personal_stats_by_kind:' || viewer::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;

  return query
  with viewer_posts as (
    select m.kind, m.primary_creator, p.action, p.rating
      from public.posts p
      join public.media m on m.id = p.media_id
     where p.author_id = viewer
  ),
  by_kind as (
    select
      vp.kind,
      count(*) filter (where vp.action in ('logged'::public.post_action, 'rated'::public.post_action)) as consumed_count,
      count(*) filter (where vp.action = 'saved'::public.post_action) as saved_count,
      count(*) filter (where vp.action = 'rated'::public.post_action) as rated_count,
      avg(vp.rating) filter (where vp.action = 'rated'::public.post_action) as avg_rating
    from viewer_posts vp
    group by vp.kind
  ),
  creator_counts as (
    select vp.kind, vp.primary_creator, count(*) as creator_count
      from viewer_posts vp
     where vp.action in ('logged'::public.post_action, 'rated'::public.post_action)
       and vp.primary_creator is not null
     group by vp.kind, vp.primary_creator
  ),
  top_creators as (
    select distinct on (cc.kind)
      cc.kind, cc.primary_creator as top_creator, cc.creator_count as top_creator_count
      from creator_counts cc
     order by cc.kind, cc.creator_count desc, cc.primary_creator asc
  )
  select
    bk.kind,
    bk.consumed_count,
    bk.saved_count,
    bk.rated_count,
    bk.avg_rating,
    tc.top_creator,
    tc.top_creator_count
  from by_kind bk
  left join top_creators tc on tc.kind = bk.kind
  order by bk.kind;
end;
$$;

revoke execute on function public.personal_stats_by_kind() from public, anon;
grant execute on function public.personal_stats_by_kind() to authenticated;

-- -----------------------------------------------------------------------------
-- personal_stats_monthly — one row per calendar month over the trailing 12
-- months (this month inclusive), zero-filled so the client always has 12
-- points to plot. Buckets by UTC month start regardless of session timezone.
-- -----------------------------------------------------------------------------
create or replace function public.personal_stats_monthly()
returns table (
  month date,
  count bigint
)
language plpgsql
security invoker
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
begin
  if viewer is null then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  if not public.rl_check('personal_stats_monthly:' || viewer::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;

  return query
  with months as (
    select generate_series(
      date_trunc('month', now() at time zone 'utc')::date - interval '11 months',
      date_trunc('month', now() at time zone 'utc')::date,
      interval '1 month'
    )::date as month
  ),
  viewer_posts as (
    select date_trunc('month', p.created_at at time zone 'utc')::date as month
      from public.posts p
     where p.author_id = viewer
       and p.action in ('logged'::public.post_action, 'rated'::public.post_action)
  )
  select mo.month, count(vp.month) as count
    from months mo
    left join viewer_posts vp on vp.month = mo.month
   group by mo.month
   order by mo.month;
end;
$$;

revoke execute on function public.personal_stats_monthly() from public, anon;
grant execute on function public.personal_stats_monthly() to authenticated;
