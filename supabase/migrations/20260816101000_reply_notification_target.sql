-- =============================================================================
-- 20260816101000_reply_notification_target.sql
-- =============================================================================
-- `notifications_target_matches_kind` enumerates which target columns each
-- kind must carry, and everything it does not name falls into an ELSE
-- requiring both post_id and comment_id to be null.
--
-- A `reply` carries both, exactly like a `comment`, so every reply
-- notification would have violated the constraint. And it would have failed
-- silently: notify_post_commented catches all exceptions on purpose, so that
-- a notification failure never costs someone their comment. Replies would
-- have notified nobody, with nothing in the logs to say so.
--
-- Found by reading the constraint rather than by testing a reply, which is
-- the only reason it is being fixed before it shipped rather than after
-- someone wondered why nobody answered them.
--
-- Idempotent: safe to replay.
-- =============================================================================

alter table public.notifications
  drop constraint if exists notifications_target_matches_kind;

alter table public.notifications
  add constraint notifications_target_matches_kind check (
    case kind
      when 'like' then post_id is not null and comment_id is null
      -- A reply points at the same pair a comment does: the post it lives on
      -- and the comment itself.
      when 'comment' then post_id is not null and comment_id is not null
      when 'reply' then post_id is not null and comment_id is not null
      else post_id is null and comment_id is null
    end
  );
