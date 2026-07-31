-- =============================================================================
-- 20260731090000_reserved_usernames.sql — block usernames that shadow static routes.
-- =============================================================================
-- Public profiles are served at the top-level `/[username]` route (web/app/
-- [username]/page.tsx) — venn.app/maya, not venn.app/u/maya, per the approved
-- URL scheme. Next.js always resolves a static route over a dynamic catch-all
-- at the same level, so a username matching one of web/app/'s static
-- top-level route segments would permanently shadow that user's own public
-- profile on web (their own profile page would never render — the static
-- route wins on every request).
--
-- The current static top-level routes under web/app/ are: auth/, login/,
-- profile/, requests/. This list must be extended whenever a new static
-- top-level route is added under web/app/.
--
-- Idempotent: safe to replay (DROP CONSTRAINT IF EXISTS / ADD CONSTRAINT).
-- =============================================================================

alter table public.profiles
  drop constraint if exists profiles_username_not_reserved,
  add constraint profiles_username_not_reserved check (
    username not in ('auth', 'login', 'profile', 'requests')
  );
