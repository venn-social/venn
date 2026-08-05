-- =============================================================================
-- 20260805100200_lists.sql — user-curated lists.
-- =============================================================================
-- Letterboxd's defining feature: "best films of 2026", "comfort rewatches",
-- "what I'd hand a stranger". Distinct from the Collection and Watchlist
-- shelves, which are derived from what you logged — a list is authored, and
-- its order is a statement.
--
-- Two tables: the list, and its items. Items reference public.media rather
-- than public.posts, because a list is about the things themselves, not
-- about anyone's logging of them — you can list a film you never logged.
--
-- `position` is an explicit integer, not created_at ordering: the point of
-- a list is that the maker chose the order.
--
-- Idempotent: safe to replay.
-- =============================================================================

create table if not exists public.lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  description text,
  is_public boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.lists
  drop constraint if exists lists_title_length,
  add constraint lists_title_length check (length(btrim(title)) between 1 and 60);

alter table public.lists
  drop constraint if exists lists_description_length,
  add constraint lists_description_length check (
    description is null or length(description) <= 500
  );

create index if not exists lists_owner_id_idx on public.lists (owner_id, created_at desc);

create table if not exists public.list_items (
  list_id uuid not null references public.lists (id) on delete cascade,
  media_id uuid not null references public.media (id) on delete cascade,
  position integer not null default 0,
  note text,
  created_at timestamptz not null default now(),
  primary key (list_id, media_id)
);

alter table public.list_items
  drop constraint if exists list_items_note_length,
  add constraint list_items_note_length check (note is null or length(note) <= 280);

-- The only read pattern: one list's items in the maker's chosen order.
create index if not exists list_items_list_id_idx on public.list_items (list_id, position asc);

alter table public.lists enable row level security;
alter table public.list_items enable row level security;

-- A public list is visible to everyone; a private one only to its owner.
-- This is per-list, deliberately independent of the account-level
-- is_private flag — a public account may still want a private list.
drop policy if exists lists_select_public_or_own on public.lists;
create policy lists_select_public_or_own
  on public.lists for select
  using (is_public or auth.uid() = owner_id);

drop policy if exists lists_insert_own on public.lists;
create policy lists_insert_own
  on public.lists for insert
  with check (auth.uid() = owner_id);

drop policy if exists lists_update_own on public.lists;
create policy lists_update_own
  on public.lists for update
  using (auth.uid() = owner_id);

drop policy if exists lists_delete_own on public.lists;
create policy lists_delete_own
  on public.lists for delete
  using (auth.uid() = owner_id);

-- Items inherit their list's visibility. Every policy re-derives it from
-- public.lists rather than duplicating the rule, so a list flipping to
-- private hides its items in the same instant.
drop policy if exists list_items_select_visible on public.list_items;
create policy list_items_select_visible
  on public.list_items for select
  using (
    exists (
      select 1 from public.lists l
      where l.id = list_id and (l.is_public or l.owner_id = auth.uid())
    )
  );

drop policy if exists list_items_write_own on public.list_items;
create policy list_items_write_own
  on public.list_items for all
  using (
    exists (select 1 from public.lists l where l.id = list_id and l.owner_id = auth.uid())
  )
  with check (
    exists (select 1 from public.lists l where l.id = list_id and l.owner_id = auth.uid())
  );

-- -----------------------------------------------------------------------------
-- Keep lists.updated_at honest — it's what "recently updated" would sort by,
-- and a timestamp nobody maintains is worse than no timestamp.
-- -----------------------------------------------------------------------------
create or replace function public.touch_list_updated_at()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists lists_touch_updated_at on public.lists;
create trigger lists_touch_updated_at
  before update on public.lists
  for each row
  execute function public.touch_list_updated_at();

-- -----------------------------------------------------------------------------
-- Rate limit on list creation — 20/minute, same reasoning as posts.
-- -----------------------------------------------------------------------------
create or replace function public.enforce_list_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.rl_check('create_list:' || new.owner_id::text, 20, interval '1 minute') then
    raise exception 'rate_limited' using errcode = 'P0429';
  end if;
  return new;
end;
$$;

drop trigger if exists lists_rate_limit on public.lists;
create trigger lists_rate_limit
  before insert on public.lists
  for each row
  execute function public.enforce_list_rate_limit();
