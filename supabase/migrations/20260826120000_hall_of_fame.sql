-- =============================================================================
-- Hall of Fame — the handful of things that represent you.
--
-- A profile currently opens with the whole collection, which is a record of
-- what you have seen rather than a statement of what you like. The hall is
-- the statement: a small, ordered set shown first, with the collection still
-- underneath as the place everything lives.
--
-- Membership and order are one column. `hall_position` null means "not in
-- the hall"; 1..12 is its place in the grid. Two constraints then do the
-- work a trigger would otherwise be needed for:
--
--   * the CHECK bounds it to 1..12,
--   * the unique index makes a position unique per person,
--
-- so a twelve-item cap is arithmetic rather than a rule someone has to
-- remember to enforce. There is no count(*) anywhere, and no race between
-- two clients both seeing eleven.
--
-- Watchlist entries are excluded. The hall is things you loved, and you
-- cannot have loved something you have not got to yet.
-- =============================================================================

alter table public.posts
  add column hall_position smallint;

alter table public.posts
  add constraint posts_hall_position_range
  check (hall_position is null or hall_position between 1 and 12);

-- Saved-for-later cannot be in the hall. Written against the action rather
-- than enforced in the client, because the client is a mirror and a mirror
-- is not an enforcement.
alter table public.posts
  add constraint posts_hall_not_watchlist
  check (hall_position is null or action <> 'saved');

-- One item per slot, per person. Combined with the range check above, this
-- is what caps the hall at twelve.
create unique index posts_hall_position_unique
  on public.posts (author_id, hall_position)
  where hall_position is not null;

-- The profile reads "this person's hall, in order" on every visit.
create index posts_hall_idx
  on public.posts (author_id, hall_position)
  where hall_position is not null;

comment on column public.posts.hall_position is
  'Place in the author''s Hall of Fame, 1-12. Null means not in it. The '
  'range check plus the unique index cap the hall at twelve without a '
  'trigger or a count.';
