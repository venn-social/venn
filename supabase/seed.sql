-- =============================================================================
-- seed.sql — demo data. LOCAL DEVELOPMENT ONLY.
-- =============================================================================
-- Runs after migrations on `npm run db:reset` (local), so local
-- environments keep the demo trio even though the remove_demo_seed
-- migration retired them from production (2026-06-12 — the remote runs
-- real data now; do NOT `npm run db:seed` against it). Re-run is safe:
-- every insert uses fixed UUIDs + ON CONFLICT DO NOTHING.
--
-- Rules:
--   - Demo / fictional data only. No real users, no real emails.
--   - Don't put secrets here.
--   - Keep it minimal — heavy fixtures slow down db:reset.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Demo auth users. Profiles FK to auth.users(id), so we have to insert at
-- both layers. Passwords are NULL — these accounts aren't meant to sign in.
-- -----------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '11111111-1111-1111-1111-111111111111',
    'authenticated', 'authenticated',
    'maya@venn.demo', now(),
    '{"provider":"seed"}', '{}', now(), now(),
    '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '22222222-2222-2222-2222-222222222222',
    'authenticated', 'authenticated',
    'theo@venn.demo', now(),
    '{"provider":"seed"}', '{}', now(), now(),
    '', '', '', ''
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '33333333-3333-3333-3333-333333333333',
    'authenticated', 'authenticated',
    'alex@venn.demo', now(),
    '{"provider":"seed"}', '{}', now(), now(),
    '', '', '', ''
  )
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Profiles.
-- -----------------------------------------------------------------------------
insert into public.profiles (id, username, display_name, bio, created_at)
values
  ('11111111-1111-1111-1111-111111111111', 'maya', 'Maya Chen',
   'movies that linger, loud dinners, albums with one perfect skip', now()),
  ('22222222-2222-2222-2222-222222222222', 'theo', 'Theo Park',
   'television writer, late-night reader, completionist about playlists', now()),
  ('33333333-3333-3333-3333-333333333333', 'alex', 'Alex Rivera',
   'fiction over non, vinyl over streaming, the right movie at the right time', now())
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Media catalog (movies + shows + books + albums).
-- -----------------------------------------------------------------------------
insert into public.media (id, kind, title, year, primary_creator, external_id, external_source, created_at)
values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'movie', 'Past Lives',          2023, 'Celine Song',     null, null, now()),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'movie', 'Aftersun',            2022, 'Charlotte Wells', null, null, now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'show',  'The Bear',            2022, 'Christopher Storer', null, null, now()),
  ('cccccccc-cccc-cccc-cccc-ccccccccccc1', 'book',  'The Hard Thing About Hard Things', 2014, 'Ben Horowitz', null, null, now()),
  ('dddddddd-dddd-dddd-dddd-ddddddddddd1', 'album', 'A Moon Shaped Pool',  2016, 'Radiohead',       null, null, now())
on conflict (id) do nothing;

-- -----------------------------------------------------------------------------
-- Posts — recent activity across the three demo users.
-- -----------------------------------------------------------------------------
insert into public.posts (id, author_id, media_id, action, rating, caption, created_at)
values
  ('11111111-aaaa-1111-aaaa-111111111111',
   '11111111-1111-1111-1111-111111111111',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
   'logged', 4.5,
   'quiet, devastating, exactly the right kind of Sunday movie',
   now() - interval '2 hours'),
  ('22222222-bbbb-2222-bbbb-222222222222',
   '22222222-2222-2222-2222-222222222222',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
   'rated', 4.0,
   'season 2 has the restaurant anxiety and the family ache',
   now() - interval '5 hours'),
  ('33333333-cccc-3333-cccc-333333333333',
   '33333333-3333-3333-3333-333333333333',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
   'logged', 5.0,
   'i did not know a movie could be this kind to its own characters',
   now() - interval '1 day'),
  ('44444444-dddd-4444-dddd-444444444444',
   '11111111-1111-1111-1111-111111111111',
   'cccccccc-cccc-cccc-cccc-ccccccccccc1',
   'saved', null, null,
   now() - interval '2 days'),
  ('55555555-eeee-5555-eeee-555555555555',
   '22222222-2222-2222-2222-222222222222',
   'dddddddd-dddd-dddd-dddd-ddddddddddd1',
   'rated', 4.5,
   'still the gold standard for "album as a single sustained mood"',
   now() - interval '3 days'),
  ('66666666-ffff-6666-ffff-666666666666',
   '33333333-3333-3333-3333-333333333333',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
   'logged', null,
   'finally caught up on season 3. carmy needs a vacation.',
   now() - interval '4 days')
on conflict (id) do nothing;
