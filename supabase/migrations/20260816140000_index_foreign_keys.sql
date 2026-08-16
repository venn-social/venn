-- =============================================================================
-- 20260816140000_index_foreign_keys.sql — index the cascading foreign keys.
-- =============================================================================
-- Five foreign keys had no index. Postgres does not create one for the
-- referencing side, so every cascading delete scans the child table under a
-- lock, and every join through the key does the same.
--
-- Two of these became more load-bearing today. Comment replies cascade on
-- delete, so removing a root comment now deletes its replies, and each of
-- those cascades into notifications — a chain of sequential scans where there
-- should be index lookups.
--
-- Cheap and uncontroversial, unlike the materialised similarity table in
-- tech-debt row 30. An index has no refresh schedule and no invalidation
-- story; it is just there. That is the difference between this and guessing
-- at a performance problem nobody can measure yet.
--
-- Idempotent: `if not exists` throughout.
-- =============================================================================

-- Deleting a post or a comment cascades here.
create index if not exists notifications_post_id_idx
  on public.notifications (post_id);
create index if not exists notifications_comment_id_idx
  on public.notifications (comment_id);

-- Deleting a profile cascades to everything they did to other people.
create index if not exists notifications_actor_id_idx
  on public.notifications (actor_id);
create index if not exists post_comments_author_id_idx
  on public.post_comments (author_id);

-- Deleting a media row cascades to every list it appears on.
create index if not exists list_items_media_id_idx
  on public.list_items (media_id);
