-- =============================================================================
-- 20260815140000_profile_language.sql — the language a person reads in.
-- =============================================================================
-- Used to ask the catalog for results in that language, so someone searching
-- in French finds the French edition rather than whatever the work's original
-- language happens to be.
--
-- It deliberately does NOT localise `media`. That table is one shared row per
-- item, referenced by everyone's posts, so a title stored there belongs to all
-- readers at once and cannot be two languages simultaneously. Whoever logs an
-- item first still decides its stored title; the preference changes what each
-- person *finds*, not what everyone else *sees*.
--
-- Constrained rather than free text, and the set is small on purpose: every
-- value here is a promise that search actually behaves differently, and
-- offering a language the providers cannot serve is worse than not offering
-- it. TMDB localises properly; Open Library only through editions; MusicBrainz
-- not at all.
--
-- Idempotent: safe to replay.
-- =============================================================================

alter table public.profiles
  add column if not exists language text not null default 'en';

alter table public.profiles
  drop constraint if exists profiles_language_supported;

alter table public.profiles
  add constraint profiles_language_supported check (
    language in ('en', 'fr', 'es', 'de', 'it', 'pt', 'ja')
  );

comment on column public.profiles.language is
  'BCP-47 primary subtag. Drives catalog search language, not stored media rows.';
