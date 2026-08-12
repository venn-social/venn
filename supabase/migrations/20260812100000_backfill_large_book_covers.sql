-- =============================================================================
-- 20260812100000_backfill_large_book_covers.sql
-- =============================================================================
-- Book covers already in `media` still point at Open Library's -M image,
-- which is 180x183 — smaller than the tile it renders into, so those rows
-- stay visibly soft even though the catalog code now asks for -L (465x475).
--
-- The code fix only affects newly fetched candidates. Anything logged
-- before it shipped keeps the URL it was stored with, so the shelves people
-- already have are exactly the ones that still look wrong.
--
-- Scoped as tightly as possible: only Open Library covers, only the -M
-- suffix, and only when the row actually has one. Other providers build
-- their URLs differently and must not be touched.
--
-- Idempotent: replaying matches nothing, because -L rows no longer end in
-- -M.jpg. Reversing it is the same statement with the two sizes swapped.
-- =============================================================================

update public.media
   set cover_url = replace(cover_url, '-M.jpg', '-L.jpg')
 where cover_url like 'https://covers.openlibrary.org/b/id/%-M.jpg';
