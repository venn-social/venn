-- =============================================================================
-- 20260816121000_restore_rl_check_grant.sql — undo a broken lockdown.
-- =============================================================================
-- The previous migration revoked rl_check from `authenticated` to stop callers
-- forging another user's rate-limit key. It checked that the trigger functions
-- were SECURITY DEFINER and would be unaffected. It did not check the RPCs.
--
-- compute_overlap, personal_stats_by_kind and personal_stats_monthly are
-- SECURITY INVOKER and call rl_check, so they ran as the caller and started
-- failing with "permission denied for function rl_check" the moment the
-- revoke landed. That is the Venn overlap and both stats screens, down.
--
-- This restores the grant so those work again. The forgery fix returns in the
-- next migration, which moves those three onto rl_check_self first — they key
-- on the viewer's own id already, so it is a direct swap.
--
-- Idempotent: safe to replay.
-- =============================================================================

grant execute on function public.rl_check(text, int, interval) to authenticated;
