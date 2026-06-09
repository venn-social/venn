-- Composite index for library queries.
-- Covers watchlist (action = 'saved') and collection (action IN ('logged','rated'))
-- filtered by author, ordered by newest first. The !inner join on media is resolved
-- before this index is consulted, so kind filtering happens client-side.
CREATE INDEX IF NOT EXISTS posts_author_action_created_idx
    ON public.posts (author_id, action, created_at DESC);
