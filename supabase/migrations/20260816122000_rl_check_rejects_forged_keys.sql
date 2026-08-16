-- =============================================================================
-- 20260816122000_rl_check_rejects_forged_keys.sql
-- =============================================================================
-- The forgery this closes: rl_check is SECURITY DEFINER, callable by
-- `authenticated`, and takes the key as an argument. So a signed-in caller
-- could spend somebody else's allowance —
--
--   rpc('rl_check', { _key: 'catalog_search:<someone-else>', ... })
--
-- — and repeat it until that person's next search was refused. One user
-- locking another out of a feature, at will.
--
-- The first attempt revoked the grant. That broke production: compute_overlap,
-- personal_stats_by_kind and personal_stats_monthly are SECURITY INVOKER and
-- call rl_check, so they ran as the caller and started failing immediately.
-- The Venn overlap and both stats screens went down until the grant was put
-- back. Checking the triggers was not enough; the RPCs needed checking too.
--
-- This fixes it where it actually belongs. Every legitimate key in the
-- codebase already ends in the caller's own id — the triggers key on
-- new.author_id, new.user_id and new.owner_id, which RLS pins to the caller,
-- and the RPCs key on auth.uid() directly. So rl_check can simply require
-- that, and no call site changes at all.
--
-- A null auth.uid() is allowed through: that is the service role or a
-- server-side session, which is trusted and has no uid to match against.
--
-- Idempotent: safe to replay.
-- =============================================================================

create or replace function public.rl_check(_key text, _limit int, _window interval)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  _count int;
  _caller uuid := auth.uid();
begin
  -- A signed-in caller may only ever spend their own allowance. Refusing
  -- rather than raising keeps this a rate-limit answer, which is what every
  -- caller already knows how to handle.
  if _caller is not null and _key not like ('%:' || _caller::text) then
    return false;
  end if;

  insert into public.rate_limits (key, ts) values (_key, now());
  -- Opportunistic cleanup keeps the table tiny without a scheduled job.
  delete from public.rate_limits where ts < now() - _window;
  select count(*) into _count
    from public.rate_limits
   where key = _key and ts > now() - _window;
  return _count <= _limit;
end;
$$;
