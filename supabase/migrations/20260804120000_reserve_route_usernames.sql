-- =============================================================================
-- 20260804120000_reserve_route_usernames.sql — extend reserved usernames.
-- =============================================================================
-- Supersedes the list in 20260731090000_reserved_usernames.sql. Public
-- profiles are served at the top-level `/[username]` route, and Next.js
-- always resolves a static route over a dynamic one at the same level, so a
-- username matching a static top-level segment under web/app/ permanently
-- shadows that user's own profile.
--
-- Phase 3 adds `feed`. The remaining names are reserved ahead of the routes
-- the phase roadmap already commits to (explorer/search in the Explorer
-- phase, composer in the Composer phase, settings alongside profile
-- settings), so each later phase does not need its own migration. Reserving
-- a name is cheap; reclaiming one after a user has taken it is not.
--
-- Verified 2026-08-04 against the live database: no existing profile holds
-- any of these names, so adding the constraint cannot fail on existing rows.
--
-- Idempotent: safe to replay (DROP CONSTRAINT IF EXISTS / ADD CONSTRAINT).
-- =============================================================================

alter table public.profiles
  drop constraint if exists profiles_username_not_reserved,
  add constraint profiles_username_not_reserved check (
    username not in (
      'auth', 'login', 'profile', 'requests',
      'feed', 'explorer', 'search', 'settings',
      'composer', 'notifications', 'about', 'terms', 'privacy'
    )
  );
