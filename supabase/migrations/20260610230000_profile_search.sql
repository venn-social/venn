-- =============================================================================
-- 20260610230000_profile_search.sql — indexes for people search.
-- =============================================================================
-- The Explorer "People" search matches profiles by username or display name
-- with a contains (ILIKE %term%) query. A plain B-tree can't serve infix
-- matches, so this adds trigram (pg_trgm) GIN indexes. Reads are already
-- allowed for everyone via the `profiles_select_all` RLS policy — no policy
-- changes here.
--
-- Idempotent: safe to replay.
-- =============================================================================

-- Supabase convention: extensions live in the `extensions` schema.
create extension if not exists pg_trgm with schema extensions;

create index if not exists profiles_username_trgm_idx
  on public.profiles using gin (username extensions.gin_trgm_ops);

create index if not exists profiles_display_name_trgm_idx
  on public.profiles using gin (display_name extensions.gin_trgm_ops);
