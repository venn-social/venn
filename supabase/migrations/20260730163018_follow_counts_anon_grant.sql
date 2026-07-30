-- =============================================================================
-- 20260730163018_follow_counts_anon_grant.sql — allow anon to call follow_counts.
-- =============================================================================
-- `follow_counts` (20260626120000_private_accounts.sql) was granted to
-- `authenticated` only, but its own docstring says it should be "safe to
-- call for any profile" — it only returns aggregate counts (no per-edge
-- data), and the underlying `follows`/`profiles` SELECT policies remain the
-- real access control. The `authenticated`-only grant broke any caller that
-- makes requests without a real Supabase session JWT attached — notably the
-- app's DEBUG preview/UI-test harness (`DebugSession`), whose synthetic
-- session is never transmitted to the network layer by design, so its reads
-- go out as `anon`. That collapsed `ProfileViewModel.load()` to a generic
-- error (42501 permission denied) for any profile view reached that way.
--
-- Idempotent: safe to replay.
-- =============================================================================

grant execute on function public.follow_counts(uuid) to anon;
