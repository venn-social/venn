-- =============================================================================
-- 20260805140000_reserve_media_route.sql — reserve /media and /notifications.
-- =============================================================================
-- Same reasoning as the earlier reservations: public profiles live at the
-- top-level `/[username]`, and Next.js resolves a static route over a
-- dynamic one, so any new static top-level segment permanently shadows that
-- username.
--
-- `media` is for the media detail pages. `notification` is added alongside
-- the already-reserved `notifications`, since which form a route ends up
-- using is a coin flip nobody should have to remember.
--
-- Verified before applying: no existing profile holds either name.
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
      'post', 'posts', 'list', 'lists',
      'media', 'notification'
    )
  );
