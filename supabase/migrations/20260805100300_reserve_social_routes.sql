-- =============================================================================
-- 20260805100300_reserve_social_routes.sql — reserve the new route segments.
-- =============================================================================
-- Same reasoning as 20260804120000: public profiles live at the top-level
-- `/[username]`, and Next.js resolves a static route over a dynamic one, so
-- any new static top-level segment permanently shadows that username.
--
-- The social layer adds /post/[id] and /lists, so `post`, `posts`, `list`,
-- and `lists` all need reserving. The singular/plural pairs are reserved
-- together because which one a route ends up using is a coin flip nobody
-- should have to remember.
--
-- Verified before applying: no existing profile holds any of these.
--
-- Idempotent: safe to replay.
-- =============================================================================

alter table public.profiles
  drop constraint if exists profiles_username_not_reserved,
  add constraint profiles_username_not_reserved check (
    username not in (
      'auth', 'login', 'profile', 'requests',
      'feed', 'explorer', 'search', 'settings',
      'composer', 'notifications', 'about', 'terms', 'privacy',
      'post', 'posts', 'list', 'lists'
    )
  );
