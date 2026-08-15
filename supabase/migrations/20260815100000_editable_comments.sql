-- =============================================================================
-- 20260815100000_editable_comments.sql — let people fix a comment.
-- =============================================================================
-- Comments could only be deleted and reposted. That is honest about the
-- conversation changing, but it costs the replies and the timestamp, and it
-- punishes a typo far harder than a typo deserves.
--
-- The original migration's objection stands and is the reason for the marker:
-- an edited comment in a thread someone already replied to rewrites history.
-- So an edit is never silent. `edited_at` is set by the database, not by the
-- client, and both platforms render it.
--
-- Three guards, because an UPDATE policy alone would allow more than editing:
--
--   1. The policy scopes updates to the author. Unlike delete, the post's
--      author is NOT included — removing someone's comment from your post is
--      moderation, rewriting it is impersonation.
--   2. A trigger pins post_id, author_id and created_at, so an update cannot
--      move a comment to another post or another name.
--   3. The same trigger sets edited_at itself, and only when the body
--      actually changed, so the marker cannot be forged or suppressed.
--
-- Deliberately no edit history table. The marker is what protects a reader;
-- a history nobody can view is storage with no purpose. If the edit trail is
-- ever wanted, it wants a UI at the same time.
--
-- Idempotent: safe to replay.
-- =============================================================================

alter table public.post_comments
  add column if not exists edited_at timestamptz;

comment on column public.post_comments.edited_at is
  'Set by trigger when the body changes. Null means never edited.';

-- -----------------------------------------------------------------------------
-- Only the author, and only the text.
-- -----------------------------------------------------------------------------

drop policy if exists post_comments_update_own on public.post_comments;
create policy post_comments_update_own
  on public.post_comments for update
  using (auth.uid() = author_id)
  with check (auth.uid() = author_id);

create or replace function public.post_comments_guard_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  -- Identity and placement are immutable; only the text may change.
  new.post_id := old.post_id;
  new.author_id := old.author_id;
  new.created_at := old.created_at;

  if new.body is distinct from old.body then
    new.edited_at := now();
  else
    new.edited_at := old.edited_at;
  end if;

  return new;
end;
$$;

drop trigger if exists post_comments_guard_update on public.post_comments;

create trigger post_comments_guard_update
  before update on public.post_comments
  for each row
  execute function public.post_comments_guard_update();
