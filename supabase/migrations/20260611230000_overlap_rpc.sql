-- =============================================================================
-- 20260611230000_overlap_rpc.sql — the Venn overlap RPC + rate limiting.
-- =============================================================================
-- compute_overlap(other_user) returns, per media kind, how many distinct
-- items the caller and the other user have each consumed (logged/rated —
-- watchlist saves are intent, not taste) and how many they share. The
-- client renders this as the Venn diagram on public profiles.
--
-- This is the repo's first RPC, so the sliding-window rate-limit machinery
-- from docs/CODING_STANDARDS.md ("Rate limiting" section) lands here too:
-- rate_limits + rl_check, then a 30 req/min per-user cap on the RPC.
--
-- Idempotent: safe to replay.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- rate_limits — sliding-window request log keyed by '<surface>:<user>'.
-- RLS enabled with no policies: clients can't touch it; only rl_check
-- (security definer) writes/reads.
-- -----------------------------------------------------------------------------
create table if not exists public.rate_limits (
  key text not null,
  ts timestamptz not null default now()
);

create index if not exists rate_limits_key_ts_idx on public.rate_limits (key, ts);

alter table public.rate_limits enable row level security;

create or replace function public.rl_check(_key text, _limit int, _window interval)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  _count int;
begin
  insert into public.rate_limits (key, ts) values (_key, now());
  -- Opportunistic cleanup keeps the table tiny without a scheduled job.
  delete from public.rate_limits where ts < now() - _window;
  select count(*) into _count
    from public.rate_limits
   where key = _key and ts > now() - _window;
  return _count <= _limit;
end;
$$;

revoke execute on function public.rl_check(text, int, interval) from public, anon;
grant execute on function public.rl_check(text, int, interval) to authenticated;

-- -----------------------------------------------------------------------------
-- compute_overlap — per-kind consumed-media overlap between the caller and
-- another user. SECURITY INVOKER: it only reads posts/media, which are
-- public under RLS anyway. Raises errcode P0429 when rate-limited — the
-- client maps that to AppError.rateLimited (see AppError.swift).
-- -----------------------------------------------------------------------------
create or replace function public.compute_overlap(other_user uuid)
returns table (
  kind public.media_kind,
  viewer_count bigint,
  other_count bigint,
  shared_count bigint
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
  if not public.rl_check('compute_overlap:' || viewer::text, 30, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;

  return query
  with viewer_media as (
    select distinct p.media_id
      from public.posts p
     where p.author_id = viewer
       and p.action in ('logged'::public.post_action, 'rated'::public.post_action)
  ),
  other_media as (
    select distinct p.media_id
      from public.posts p
     where p.author_id = other_user
       and p.action in ('logged'::public.post_action, 'rated'::public.post_action)
  )
  select
    m.kind,
    count(*) filter (where v.media_id is not null) as viewer_count,
    count(*) filter (where o.media_id is not null) as other_count,
    count(*) filter (where v.media_id is not null and o.media_id is not null) as shared_count
  from public.media m
  left join viewer_media v on v.media_id = m.id
  left join other_media o on o.media_id = m.id
  where v.media_id is not null or o.media_id is not null
  group by m.kind
  order by m.kind;
end;
$$;

revoke execute on function public.compute_overlap(uuid) from public, anon;
grant execute on function public.compute_overlap(uuid) to authenticated;
