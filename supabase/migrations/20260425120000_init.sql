-- =============================================================================
-- 20260425120000_init.sql — initial schema for venn.
-- =============================================================================
-- Profiles + posts + Row-Level Security + sanitization CHECK constraints.
--
-- Idempotent: every statement uses IF NOT EXISTS / DROP IF EXISTS so it can
-- be applied against a fresh database OR one that was already initialized
-- via the legacy SQL block in docs/SUPABASE_SETUP.md.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- profiles — extends auth.users with app-level profile data.
-- -----------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  avatar_url text,
  bio text,
  created_at timestamptz not null default now()
);

-- DB-level enforcement of the bounds in apps/mobile/src/utils/sanitize.ts.
alter table public.profiles
  drop constraint if exists profiles_username_format,
  add constraint profiles_username_format check (
    username ~ '^[a-z0-9_-]{3,24}$'
  );

alter table public.profiles
  drop constraint if exists profiles_display_name_length,
  add constraint profiles_display_name_length check (
    display_name is null or (length(display_name) between 1 and 40)
  );

alter table public.profiles
  drop constraint if exists profiles_bio_length,
  add constraint profiles_bio_length check (
    bio is null or length(bio) <= 160
  );

-- -----------------------------------------------------------------------------
-- posts — feed items.
-- -----------------------------------------------------------------------------
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null,
  media_url text,
  like_count integer not null default 0,
  comment_count integer not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists posts_author_id_idx on public.posts (author_id);

alter table public.posts
  drop constraint if exists posts_caption_length,
  add constraint posts_caption_length check (
    length(caption) between 1 and 500
  );

-- -----------------------------------------------------------------------------
-- Row-Level Security — the golden rule of Supabase.
-- -----------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.posts enable row level security;

-- Anyone can read profiles and posts (public-by-default per product vision).
drop policy if exists profiles_select_all on public.profiles;
create policy profiles_select_all
  on public.profiles for select
  using (true);

drop policy if exists posts_select_all on public.posts;
create policy posts_select_all
  on public.posts for select
  using (true);

-- Users can only insert/update their own profile.
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles for update
  using (auth.uid() = id);

-- Users can only insert posts as themselves, and only edit/delete their own.
drop policy if exists posts_insert_own on public.posts;
create policy posts_insert_own
  on public.posts for insert
  with check (auth.uid() = author_id);

drop policy if exists posts_update_own on public.posts;
create policy posts_update_own
  on public.posts for update
  using (auth.uid() = author_id);

drop policy if exists posts_delete_own on public.posts;
create policy posts_delete_own
  on public.posts for delete
  using (auth.uid() = author_id);
