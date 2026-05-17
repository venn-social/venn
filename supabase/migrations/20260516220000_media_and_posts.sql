-- =============================================================================
-- 20260516220000_media_and_posts.sql — rewrite posts around a media catalog.
-- =============================================================================
-- The init migration shipped a placeholder `posts` schema (caption + generic
-- media_url) that doesn't match the venn data model: a venn post is about
-- *something a user consumed* — a movie, show, book, or album. This
-- migration drops the placeholder and introduces the real shape:
--
--   media    — polymorphic catalog of consumable things, keyed by
--              (external_source, external_id) when sourced from an API
--              (TMDB / OpenLibrary / MusicBrainz / ...) or freely typed
--              by the user when not.
--   posts    — references media; carries the action (logged/rated/saved),
--              an optional rating, and an optional caption.
--   follows  — directed edges in the social graph.
--
-- Destructive: drops the existing `posts` table (and its policies/indexes
-- via cascade). Pre-launch, no production data — safe at this stage but
-- DO NOT REPLAY against any DB that ever held real posts.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- media — the catalog of things people log. Polymorphic on `kind`.
-- -----------------------------------------------------------------------------
do $$ begin
  create type public.media_kind as enum ('movie', 'show', 'book', 'album');
exception when duplicate_object then null; end $$;

create table if not exists public.media (
  id uuid primary key default gen_random_uuid(),
  kind public.media_kind not null,
  title text not null,
  year smallint,
  primary_creator text,          -- director / showrunner / author / artist
  cover_url text,
  external_id text,              -- TMDB id, OpenLibrary id, MusicBrainz id...
  external_source text,          -- 'tmdb' / 'openlibrary' / 'musicbrainz' / null = user-typed
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists media_kind_idx on public.media (kind);

-- One media row per (source, external_id) when both are present.
create unique index if not exists media_external_unique
  on public.media (external_source, external_id)
  where external_source is not null and external_id is not null;

alter table public.media
  drop constraint if exists media_title_length,
  add constraint media_title_length check (length(title) between 1 and 200);

alter table public.media
  drop constraint if exists media_year_range,
  add constraint media_year_range check (year is null or year between 1800 and 2200);

alter table public.media
  drop constraint if exists media_primary_creator_length,
  add constraint media_primary_creator_length check (
    primary_creator is null or length(primary_creator) <= 120
  );

-- -----------------------------------------------------------------------------
-- posts — feed items, each about exactly one media row.
-- -----------------------------------------------------------------------------
drop table if exists public.posts cascade;

do $$ begin
  create type public.post_action as enum ('logged', 'rated', 'saved');
exception when duplicate_object then null; end $$;

create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  action public.post_action not null,
  rating numeric(2, 1),          -- 0.0 — 5.0, half-step; null = no rating
  caption text,                  -- optional; the action+media speak for themselves
  created_at timestamptz not null default now()
);

create index posts_created_at_idx on public.posts (created_at desc);
create index posts_author_id_idx on public.posts (author_id);
create index posts_media_id_idx on public.posts (media_id);

alter table public.posts
  add constraint posts_rating_range check (rating is null or (rating >= 0 and rating <= 5));

alter table public.posts
  add constraint posts_caption_length check (
    caption is null or length(caption) between 1 and 500
  );

-- -----------------------------------------------------------------------------
-- follows — directed edges in the social graph.
-- -----------------------------------------------------------------------------
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followee_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followee_id)
);

create index if not exists follows_followee_id_idx on public.follows (followee_id);

alter table public.follows
  drop constraint if exists follows_no_self_follow,
  add constraint follows_no_self_follow check (follower_id <> followee_id);

-- -----------------------------------------------------------------------------
-- Row-Level Security.
-- -----------------------------------------------------------------------------
alter table public.media enable row level security;
alter table public.posts enable row level security;
alter table public.follows enable row level security;

-- media: public read (catalog is a public lookup); authenticated insert
-- (the client adds entries when a user logs an item that doesn't exist yet).
-- No update/delete from the client — catalog mutations happen server-side
-- once we have moderation surfaces.
drop policy if exists media_select_all on public.media;
create policy media_select_all on public.media for select using (true);

drop policy if exists media_insert_authenticated on public.media;
create policy media_insert_authenticated on public.media for insert
  to authenticated with check (true);

-- posts: public read (feed is public-by-default per product vision);
-- owner-only writes/edits/deletes.
drop policy if exists posts_select_all on public.posts;
create policy posts_select_all on public.posts for select using (true);

drop policy if exists posts_insert_own on public.posts;
create policy posts_insert_own on public.posts for insert
  with check (auth.uid() = author_id);

drop policy if exists posts_update_own on public.posts;
create policy posts_update_own on public.posts for update
  using (auth.uid() = author_id);

drop policy if exists posts_delete_own on public.posts;
create policy posts_delete_own on public.posts for delete
  using (auth.uid() = author_id);

-- follows: public read (the graph is public); owner-only writes/deletes.
-- No update — follows are append-only; to "unfollow" we delete.
drop policy if exists follows_select_all on public.follows;
create policy follows_select_all on public.follows for select using (true);

drop policy if exists follows_insert_own on public.follows;
create policy follows_insert_own on public.follows for insert
  with check (auth.uid() = follower_id);

drop policy if exists follows_delete_own on public.follows;
create policy follows_delete_own on public.follows for delete
  using (auth.uid() = follower_id);
