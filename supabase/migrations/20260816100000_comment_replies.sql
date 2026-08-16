-- =============================================================================
-- 20260816100000_comment_replies.sql — replies, exactly one level deep.
-- =============================================================================
-- Comments were flat, so "@ada I meant the other one" was the only way to
-- answer someone and it read as a new remark to everyone else.
--
-- Deliberately two levels, not arbitrary depth. The tech-debt row suggested a
-- depth cap and a recursive read; a cap of one removes the need for the
-- recursion entirely — every comment is either a root or a reply to a root,
-- so the client groups a flat fetch and no recursive CTE exists to get wrong.
-- Deep threads are also close to unreadable on a phone, which is the screen
-- this product is for.
--
-- The cap is enforced in the database rather than by the clients. A reply to
-- a reply would otherwise be one mistaken insert away, and nothing in the
-- read path would notice until a thread rendered wrongly.
--
-- Replies notify the parent's author with a new `reply` kind rather than
-- reusing `comment`, which renders as "commented on your post" — wrong for
-- someone answering your remark on a stranger's post.
--
-- Idempotent: safe to replay.
-- =============================================================================

alter table public.post_comments
  add column if not exists parent_id uuid references public.post_comments (id) on delete cascade;

-- Replies are read by parent, and always for one post at a time.
create index if not exists post_comments_parent_id_idx
  on public.post_comments (parent_id, created_at asc);

-- -----------------------------------------------------------------------------
-- One level, enforced.
-- -----------------------------------------------------------------------------

create or replace function public.post_comments_enforce_depth()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  parent record;
begin
  if new.parent_id is null then
    return new;
  end if;

  select post_id, parent_id into parent
    from public.post_comments
   where id = new.parent_id;

  if parent is null then
    raise exception 'Parent comment does not exist';
  end if;
  if parent.parent_id is not null then
    raise exception 'Replies are one level deep';
  end if;
  -- A reply belonging to a different post than its parent would appear under
  -- neither thread correctly.
  if parent.post_id is distinct from new.post_id then
    raise exception 'A reply must be on the same post as its parent';
  end if;

  return new;
end;
$$;

drop trigger if exists post_comments_enforce_depth on public.post_comments;

create trigger post_comments_enforce_depth
  before insert or update on public.post_comments
  for each row
  execute function public.post_comments_enforce_depth();

-- -----------------------------------------------------------------------------
-- Tell the person actually being answered.
-- -----------------------------------------------------------------------------

alter table public.notifications
  drop constraint if exists notifications_kind_valid;

alter table public.notifications
  add constraint notifications_kind_valid check (
    kind in ('like', 'comment', 'follow', 'follow_request', 'reply')
  );

create or replace function public.notify_post_commented()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  recipient uuid;
begin
  if new.parent_id is null then
    select author_id into recipient from public.posts where id = new.post_id;
    perform public.create_notification(
      recipient, new.author_id, 'comment', new.post_id, new.id
    );
  else
    -- The parent's author, not the post's: they are the one being answered,
    -- and create_notification already drops the self-reply case.
    select author_id into recipient
      from public.post_comments
     where id = new.parent_id;
    perform public.create_notification(
      recipient, new.author_id, 'reply', new.post_id, new.id
    );
  end if;
  return new;
exception
  when others then
    -- Unchanged from the original: a notification failure must never cost
    -- someone their comment.
    return new;
end;
$$;
