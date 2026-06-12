-- =============================================================================
-- 20260612180000_remove_demo_seed.sql — retire demo data; add the official
-- venn account.
-- =============================================================================
-- The app is switching to real data (real profiles, real logs, real cover
-- art). This migration removes the three fictional users that seed.sql
-- planted on the remote during early development — deleting their
-- auth.users rows cascades through profiles → posts → follows — plus the
-- seeded media rows nothing references anymore.
--
-- It also creates the **official venn account** (@venn): a stable,
-- passwordless account that gives new users someone to find in People
-- search and gives the UI tests a stable anchor that isn't a fictional
-- person or anyone's personal account.
--
-- Local dev is unaffected: `npm run db:reset` applies migrations first and
-- seed.sql afterwards, so local environments keep the demo trio.
--
-- Idempotent: safe to replay.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Remove the demo users. The provider='seed' guard ensures we can never
-- delete a real account that somehow ended up with a demo UUID.
-- -----------------------------------------------------------------------------
delete from auth.users
where id in (
  '11111111-1111-1111-1111-111111111111',
  '22222222-2222-2222-2222-222222222222',
  '33333333-3333-3333-3333-333333333333'
)
and raw_app_meta_data ->> 'provider' = 'seed';

-- -----------------------------------------------------------------------------
-- Remove the seeded media rows — but only those no surviving post
-- references (a real post can't reference them today, since real logs
-- create media rows with external ids; the guard is belt-and-suspenders).
-- -----------------------------------------------------------------------------
delete from public.media m
where m.id in (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1',
  'cccccccc-cccc-cccc-cccc-ccccccccccc1',
  'dddddddd-dddd-dddd-dddd-ddddddddddd1'
)
and not exists (select 1 from public.posts p where p.media_id = m.id);

-- -----------------------------------------------------------------------------
-- The official venn account. Passwordless (can't sign in); the team can
-- attach a real credential later via the dashboard if it ever needs to
-- post. provider='system' distinguishes it from both seed data and humans.
-- -----------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
values (
  '00000000-0000-0000-0000-000000000000',
  '99999999-9999-9999-9999-999999999999',
  'authenticated', 'authenticated',
  'team@venn.social', now(),
  '{"provider":"system"}', '{}', now(), now(),
  '', '', '', ''
)
on conflict (id) do nothing;

insert into public.profiles (id, username, display_name, bio, created_at)
values (
  '99999999-9999-9999-9999-999999999999',
  'venn', 'Venn',
  'The official venn account.',
  now()
)
on conflict (id) do nothing;
