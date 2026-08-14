-- =============================================================================
-- 20260814100000_backfill_english_book_titles.sql
-- =============================================================================
-- Three books were stored under their original-language title, because Open
-- Library's search returns the *work's* canonical title and the app did not
-- ask for the edition that matched the query. The catalog code now does, so
-- new searches are correct — but rows logged before that keep what they were
-- written with.
--
-- Values come from the same request the app now makes: searching the English
-- title, matching on the stored work key, and taking that edition's title and
-- cover. They are inlined because Postgres cannot call the API, and derived
-- rather than typed by hand so the result matches what a re-log would produce.
--
-- Cover and title move together, as they do in the code. Each new cover was
-- fetched and measured first; all three are 500px tall, against 192-276
-- before.
--
-- Guarded on the current title, so this is idempotent and cannot overwrite a
-- title someone has since corrected by hand.
-- =============================================================================

update public.media
   set title = 'Perfume',
       cover_url = 'https://covers.openlibrary.org/b/id/253767-L.jpg'
 where external_source = 'openlibrary'
   and external_id = 'OL10834W'
   and title = 'Das Parfum';

update public.media
   set title = 'The Stranger',
       cover_url = 'https://covers.openlibrary.org/b/id/15118287-L.jpg'
 where external_source = 'openlibrary'
   and external_id = 'OL1230613W'
   and title = 'L’étranger';

update public.media
   set title = 'Kafka on the Shore',
       cover_url = 'https://covers.openlibrary.org/b/id/11522102-L.jpg'
 where external_source = 'openlibrary'
   and external_id = 'OL2625431W'
   and title = '海辺のカフカ';

-- Authors are deliberately untouched. Open Library returns 村上春樹 for this
-- work even on its English edition, so overriding it here would make the row
-- disagree with what the app itself produces on the next search.
