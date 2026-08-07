-- =============================================================================
-- 20260807110000_one_post_per_item.sql — one row per person per item.
-- =============================================================================
-- Logging something and then rating it created two `posts` rows. Both
-- platforms build the collection from raw post rows filtered to
-- ('logged','rated'), so one item you consumed once showed up twice.
--
-- The model is now: one row per (author, media). `action` carries the
-- current state (saved -> logged -> rated) and rating updates in place.
--
-- Three things happen here, in order:
--
--   1. Existing duplicates collapse onto a survivor.
--   2. Likes and comments are re-pointed at that survivor first, because
--      post_likes / post_comments / notifications all cascade on delete —
--      collapsing naively would silently destroy other people's likes and
--      comments.
--   3. A unique constraint stops it recurring, and a trigger keeps the
--      surviving row's timestamp meaningful.
--
-- Survivor precedence is rated > logged > saved, then newest, then id for
-- determinism: the most informative row wins, so a rating is never lost to
-- a bare log.
--
-- Idempotent: safe to replay. On a database with no duplicates, steps 1-2
-- are no-ops.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Work out who survives.
-- -----------------------------------------------------------------------------

create temporary table _collapse on commit drop as
with ranked as (
  select p.id,
         p.author_id,
         p.media_id,
         row_number() over (
           partition by p.author_id, p.media_id
           order by case p.action
                      when 'rated'  then 0
                      when 'logged' then 1
                      else 2
                    end,
                    p.created_at desc,
                    p.id
         ) as rn
    from public.posts p
),
survivors as (
  select author_id, media_id, id as keep_id
    from ranked
   where rn = 1
)
select r.id as loser_id, s.keep_id
  from ranked r
  join survivors s
    on s.author_id = r.author_id
   and s.media_id = r.media_id
 where r.rn > 1;

-- -----------------------------------------------------------------------------
-- 2. Move likes and comments across before anything is deleted.
-- -----------------------------------------------------------------------------

-- A user may have liked both rows. post_likes is keyed (post_id, user_id),
-- so drop the redundant like rather than collide on re-point.
delete from public.post_likes l
 using _collapse c
 where l.post_id = c.loser_id
   and exists (
     select 1 from public.post_likes keep
      where keep.post_id = c.keep_id
        and keep.user_id = l.user_id
   );

update public.post_likes l
   set post_id = c.keep_id
  from _collapse c
 where l.post_id = c.loser_id;

update public.post_comments cm
   set post_id = c.keep_id
  from _collapse c
 where cm.post_id = c.loser_id;

-- Notifications point at a post for deep-linking. Re-point rather than let
-- them cascade, so an existing "liked your post" still opens something.
update public.notifications n
   set post_id = c.keep_id
  from _collapse c
 where n.post_id = c.loser_id;

-- -----------------------------------------------------------------------------
-- 3. Collapse, constrain, and keep the timestamp honest.
-- -----------------------------------------------------------------------------

delete from public.posts p
 using _collapse c
 where p.id = c.loser_id;

alter table public.posts
  drop constraint if exists posts_one_per_author_media;

alter table public.posts
  add constraint posts_one_per_author_media unique (author_id, media_id);

-- With one row per item, a later rating has to move the row forward in the
-- feed or it would never surface to friends — it would sit at the moment
-- the item was first saved or logged, possibly weeks earlier. Done in a
-- trigger so both clients stay identical and neither has to send a
-- timestamp.
create or replace function public.posts_touch_on_state_change()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.action is distinct from old.action
     or new.rating is distinct from old.rating then
    new.created_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists posts_touch_on_state_change on public.posts;

create trigger posts_touch_on_state_change
  before update on public.posts
  for each row
  execute function public.posts_touch_on_state_change();
