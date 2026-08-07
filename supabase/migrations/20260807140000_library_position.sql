-- =============================================================================
-- 20260807140000_library_position.sql — let people arrange their own shelves.
-- =============================================================================
-- Collection and watchlist have always been ordered newest-first, which is
-- the right default and the wrong only option: a shelf is something people
-- want to curate, and the thing you are proudest of is rarely the thing you
-- logged most recently.
--
-- `position` is nullable on purpose. Null means "never been placed", and
-- sorts after everything that has, newest-first among itself. So a shelf
-- nobody has touched behaves exactly as it does today, a newly logged item
-- appears at the top of the unplaced group rather than jumping into the
-- middle of a curated run, and no backfill is needed.
--
-- Ordering is therefore: position asc nulls last, created_at desc.
--
-- Idempotent: safe to replay.
-- =============================================================================

alter table public.posts
  add column if not exists position integer;

-- The read pattern is "one author's shelf, in order". Partial on non-null
-- because the unplaced majority is served by the created_at ordering.
create index if not exists posts_author_position_idx
  on public.posts (author_id, position asc)
  where position is not null;

-- -----------------------------------------------------------------------------
-- Reordering
-- -----------------------------------------------------------------------------
-- Takes the whole desired order rather than a moved pair, for the same two
-- reasons as reorder_list_items: one statement is atomic, so a failure
-- cannot leave two items claiming one slot; and it repairs a shelf whose
-- positions have already drifted.
--
-- `security invoker`, so posts' own RLS decides whose rows these are. The
-- author_id check is belt-and-braces: a caller passing someone else's post
-- ids updates zero rows either way.
create or replace function public.reorder_library_items(_post_ids uuid[])
returns void
language sql
security invoker
set search_path = ''
as $$
  update public.posts p
     set position = ordered.position
    from (
      select post_id, (ordinality - 1)::int as position
        from unnest(_post_ids) with ordinality as t (post_id, ordinality)
    ) as ordered
   where p.id = ordered.post_id
     and p.author_id = (select auth.uid());
$$;

revoke execute on function public.reorder_library_items(uuid[]) from public, anon;
grant execute on function public.reorder_library_items(uuid[]) to authenticated;
