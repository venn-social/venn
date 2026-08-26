-- =============================================================================
-- reorder_hall — drag the Hall of Fame into the order you want.
--
-- The profile's shelves already reorder by drag, through
-- `reorder_library_items`, which writes `posts.position`. The hall is
-- ordered by `hall_position` instead, so that function silently did nothing
-- for it: dragging a starred cover moved it on screen, wrote the wrong
-- column, and the old order came back on the next load. This is the
-- matching function for the column the hall actually reads.
--
-- Why this one clears before it writes, and its sibling does not:
-- `hall_position` carries a unique index per author, and `position` does
-- not. A single UPDATE that permutes positions checks uniqueness row by
-- row, so the moment a swap writes 1 onto the row that is about to give up
-- its 1, the statement fails. The usual dodge — offset everything into
-- negative space first — is closed off too, because the CHECK that caps the
-- hall also bounds the column to 1..12.
--
-- So: null the whole hall, then write the new order. Null is the one value
-- the unique index ignores and the check allows, and both statements are in
-- one function call, so a failure in the second leaves the first rolled
-- back rather than an emptied hall.
--
-- Positions are 1-based, unlike the shelves' 0-based `position`, because
-- that is what the CHECK accepts.
--
-- `security invoker`, so posts' own RLS decides whose rows these are. The
-- author_id checks are belt-and-braces: a caller passing someone else's
-- post ids touches zero rows either way.
-- =============================================================================

create or replace function public.reorder_hall(_post_ids uuid[])
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  update public.posts
     set hall_position = null
   where author_id = (select auth.uid())
     and hall_position is not null;

  update public.posts p
     set hall_position = ordered.position
    from (
      select post_id, ordinality::smallint as position
        from unnest(_post_ids) with ordinality as t (post_id, ordinality)
    ) as ordered
   where p.id = ordered.post_id
     and p.author_id = (select auth.uid());
end;
$$;

revoke execute on function public.reorder_hall(uuid[]) from public, anon;
grant execute on function public.reorder_hall(uuid[]) to authenticated;
