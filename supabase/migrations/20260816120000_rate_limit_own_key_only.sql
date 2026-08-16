-- =============================================================================
-- 20260816120000_rate_limit_own_key_only.sql
-- =============================================================================
-- `rl_check` takes the rate-limit key as an argument, is SECURITY DEFINER, and
-- was granted to `authenticated`. So any signed-in person could call it with
-- somebody else's key:
--
--   rpc('rl_check', { _key: 'catalog_search:<someone-else>', ... })
--
-- Each call inserts a row under that key. Repeat it and the victim's next
-- search is refused with "Too many searches" — one user locking another out of
-- a feature, at will, with a single public RPC. It also lets anyone fill
-- `rate_limits` with rows for keys that do not exist.
--
-- The nine callers inside triggers and definer RPCs are unaffected: they build
-- keys from an id the server already knows and run as the function owner, so
-- they never needed the client-facing grant.
--
-- Only one caller did — the catalog search route — and it passed
-- 'catalog_search:' || its own user id. So the fix is to stop clients naming
-- keys at all. `rl_check_self` takes the action and derives the identity from
-- auth.uid(), which a caller cannot forge.
--
-- Idempotent: safe to replay.
-- =============================================================================

create or replace function public.rl_check_self(
  _action text,
  _limit int,
  _window interval
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- No session, no allowance. Returning false rather than raising keeps this
  -- a rate-limit answer rather than an error the caller has to special-case.
  if auth.uid() is null then
    return false;
  end if;

  return public.rl_check(_action || ':' || auth.uid()::text, _limit, _window);
end;
$$;

revoke execute on function public.rl_check_self(text, int, interval) from public, anon;
grant execute on function public.rl_check_self(text, int, interval) to authenticated;

-- The key-taking version is now server-side only. Triggers and definer RPCs
-- call it as the owner and are unaffected.
revoke execute on function public.rl_check(text, int, interval)
  from public, anon, authenticated;
