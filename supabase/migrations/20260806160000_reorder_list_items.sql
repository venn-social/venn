-- =============================================================================
-- 20260806160000_reorder_list_items.sql — let people order their own lists.
-- =============================================================================
-- `list_items.position` has existed since lists shipped, and so has an
-- owner-scoped write policy covering UPDATE. Nothing could set it: a list
-- was always in insert order. (Tech-debt row 23 claimed the column was
-- missing; it was not.)
--
-- This takes the whole desired order and rewrites it, rather than swapping
-- a pair. Two reasons:
--
--   1. One statement is atomic. Swapping a pair from the client is two
--      UPDATEs, and a failure between them leaves two items claiming the
--      same slot with no way for the user to tell.
--   2. It is self-healing. Any list that has already drifted — duplicate
--      positions, gaps — comes back consistent the first time anyone
--      reorders it.
--
-- `security invoker`, so `list_items_write_own` decides whether the caller
-- may touch this list. Someone else's list simply updates zero rows.
--
-- Idempotent: safe to replay.
-- =============================================================================

create or replace function public.reorder_list_items(
  _list_id uuid,
  _media_ids uuid[]
)
returns void
language sql
security invoker
set search_path = ''
as $$
  update public.list_items li
     set position = ordered.position
    from (
      select media_id, (ordinality - 1)::int as position
        from unnest(_media_ids) with ordinality as t (media_id, ordinality)
    ) as ordered
   where li.list_id = _list_id
     and li.media_id = ordered.media_id;
$$;

revoke execute on function public.reorder_list_items(uuid, uuid[]) from public, anon;
grant execute on function public.reorder_list_items(uuid, uuid[]) to authenticated;
