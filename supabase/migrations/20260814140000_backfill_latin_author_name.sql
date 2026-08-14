-- =============================================================================
-- 20260814140000_backfill_latin_author_name.sql
-- =============================================================================
-- Kafka on the Shore is credited to 村上春樹, which most readers of an
-- English app cannot read, search for, or say out loud. The catalog now
-- resolves the Latin form at search time, so a fresh log would store
-- "Haruki Murakami" — but this row predates that.
--
-- The value is Open Library's own `personal_name` for that author record,
-- "Murakami, Haruki", flipped to given-name-first exactly as the app does.
-- It is not a translation typed by hand.
--
-- Deliberately one row, addressed by author and current value rather than by
-- a script test. A pattern like "any creator containing a non-Latin
-- character" also matches Patrick Süskind, whose name is Latin and correct;
-- Postgres range comparisons follow collation rather than code points, so
-- that check is not safe to automate here. Diacritics must survive.
--
-- Idempotent, and cannot overwrite a name someone has since corrected.
-- =============================================================================

update public.media
   set primary_creator = 'Haruki Murakami'
 where external_source = 'openlibrary'
   and external_id = 'OL2625431W'
   and primary_creator = '村上春樹';
