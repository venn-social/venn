"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Avatar } from "@/components/Avatar";
import {
  addComment,
  deleteComment,
  editComment,
  toThreads,
  type PostComment
} from "@/lib/comments";
import { shortRelativeTime } from "@/lib/relativeTime";
import { sanitizeCaption } from "@/lib/sanitize";
import { createClient } from "@/lib/supabase/client";

interface CommentThreadProps {
  postId: string;
  /** The signed-in viewer. */
  userId: string;
  /** The post's author — they can delete any comment on their own post. */
  postAuthorId: string;
  initialComments: PostComment[];
}

/**
 * A post's comments, oldest first, with a composer underneath.
 *
 * Replies are one level deep and the database enforces it, so this renders a
 * root and its replies and never recurses. Only roots offer a Reply button,
 * which matches what the database would accept — an affordance that leads to
 * a rejected write is worse than no affordance.
 */
export function CommentThread({
  postId,
  userId,
  postAuthorId,
  initialComments
}: CommentThreadProps) {
  const router = useRouter();
  const [comments, setComments] = useState(initialComments);
  const [body, setBody] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  /** The comment being edited, and its working text. */
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState("");
  /** The comment being replied to, and the reply text. */
  const [replyingTo, setReplyingTo] = useState<string | null>(null);
  const [replyDraft, setReplyDraft] = useState("");

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError("");

    // Comments share the caption validator — same 1-500 bound, and the
    // post_comments_body_length constraint is the final say.
    const result = sanitizeCaption(body);
    if (!result.valid) {
      setError(
        result.reason === "empty" ? "Write something first." : "Comments max out at 500 characters."
      );
      return;
    }

    setSubmitting(true);
    try {
      await addComment(createClient(), postId, userId, result.value);
      setBody("");
      router.refresh();
    } catch (submitError) {
      setError(
        (submitError as { code?: string } | null)?.code === "P0429"
          ? "You're commenting very fast — give it a moment."
          : "Couldn't post that. Please try again."
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleReply(parentId: string) {
    const result = sanitizeCaption(replyDraft);
    if (!result.valid) {
      setError(
        result.reason === "empty" ? "Write something first." : "Replies max out at 500 characters."
      );
      return;
    }

    try {
      await addComment(createClient(), postId, userId, result.value, parentId);
      setReplyingTo(null);
      setReplyDraft("");
      router.refresh();
    } catch {
      setError("Couldn't post that reply. Please try again.");
    }
  }

  async function handleEdit(commentId: string) {
    const next = draft.trim();
    if (!next) return;

    try {
      await editComment(createClient(), commentId, next);
      // Mirror what the database did rather than refetching: it stamps
      // edited_at, so showing the marker immediately keeps the edit as
      // visible here as it is to everyone else.
      setComments((current) =>
        current.map((comment) =>
          comment.id === commentId ? { ...comment, body: next, editedAt: new Date() } : comment
        )
      );
      setEditingId(null);
    } catch {
      setError("Couldn't save that edit. Please try again.");
    }
  }

  async function handleDelete(commentId: string) {
    const previous = comments;
    setComments((current) => current.filter((comment) => comment.id !== commentId));
    try {
      await deleteComment(createClient(), commentId);
      router.refresh();
    } catch {
      setComments(previous);
    }
  }

  /** One comment. `isReply` indents it and withholds its own Reply button. */
  function renderComment(comment: PostComment, isReply: boolean) {
    const name = comment.author.displayName ?? comment.author.username;
    // The RLS policy allows both; mirroring it here keeps the button from
    // appearing where the delete would be refused.
    const canDelete = userId === comment.author.id || userId === postAuthorId;
    // Editing is the author's alone. Removing someone's comment from your own
    // post is moderation; rewriting it is impersonation, so the post's author
    // deliberately does not get this.
    const canEdit = userId === comment.author.id;
    const isEditing = editingId === comment.id;

    return (
      <li key={comment.id} className={isReply ? "flex gap-3 pl-11" : "flex gap-3"}>
        <Avatar name={name} avatarUrl={comment.author.avatarUrl} size={isReply ? 24 : 32} />
        <div className="flex flex-1 flex-col gap-0.5">
          <div className="flex items-baseline gap-2">
            <span className="text-sm font-medium text-(--color-text-primary)">{name}</span>
            <span className="text-xs text-(--color-text-secondary)">
              {shortRelativeTime(comment.createdAt)}
            </span>
            {comment.editedAt && (
              <span className="text-xs text-(--color-text-secondary)">(edited)</span>
            )}
            <span className="ml-auto flex gap-3">
              {!isReply && (
                <button
                  type="button"
                  onClick={() => {
                    setReplyingTo(comment.id);
                    setReplyDraft("");
                  }}
                  className="text-xs text-(--color-text-secondary) hover:text-(--color-text-primary)"
                >
                  Reply
                </button>
              )}
              {canEdit && !isEditing && (
                <button
                  type="button"
                  onClick={() => {
                    setEditingId(comment.id);
                    setDraft(comment.body);
                  }}
                  className="text-xs text-(--color-text-secondary) hover:text-(--color-text-primary)"
                >
                  Edit
                </button>
              )}
              {canDelete && (
                <button
                  type="button"
                  onClick={() => void handleDelete(comment.id)}
                  className="text-xs text-(--color-text-secondary) hover:text-red-500"
                >
                  Delete
                </button>
              )}
            </span>
          </div>
          {isEditing ? (
            <form
              onSubmit={(event) => {
                event.preventDefault();
                void handleEdit(comment.id);
              }}
              className="flex flex-col gap-2 pt-1"
            >
              <textarea
                value={draft}
                onChange={(event) => setDraft(event.target.value)}
                rows={2}
                maxLength={500}
                aria-label="Edit your comment"
                className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
              />
              <span className="flex gap-2">
                <button
                  type="submit"
                  disabled={draft.trim().length === 0 || draft.trim() === comment.body}
                  className="rounded-pill bg-(--color-accent) px-3 py-1 text-sm font-semibold text-(--color-on-accent) disabled:opacity-50"
                >
                  Save
                </button>
                <button
                  type="button"
                  onClick={() => setEditingId(null)}
                  className="text-sm font-semibold text-(--color-text-secondary)"
                >
                  Cancel
                </button>
              </span>
            </form>
          ) : (
            <p className="text-(--color-text-primary)">{comment.body}</p>
          )}
        </div>
      </li>
    );
  }

  return (
    <section className="flex flex-col gap-4">
      <h2 className="font-semibold text-(--color-text-primary)">
        {comments.length === 0
          ? "Comments"
          : `${comments.length} ${comments.length === 1 ? "comment" : "comments"}`}
      </h2>

      {comments.length === 0 ? (
        <p className="text-(--color-text-secondary)">No comments yet. Say something.</p>
      ) : (
        <ul className="flex flex-col gap-4">
          {toThreads(comments).map(({ comment, replies }) => (
            <li key={comment.id} className="flex flex-col gap-3">
              <ul>{renderComment(comment, false)}</ul>

              {replyingTo === comment.id && (
                <form
                  onSubmit={(event) => {
                    event.preventDefault();
                    void handleReply(comment.id);
                  }}
                  className="flex flex-col gap-2 pl-11"
                >
                  <textarea
                    value={replyDraft}
                    onChange={(event) => setReplyDraft(event.target.value)}
                    rows={2}
                    maxLength={500}
                    aria-label={`Reply to ${comment.author.displayName ?? comment.author.username}`}
                    className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
                  />
                  <span className="flex gap-2">
                    <button
                      type="submit"
                      disabled={replyDraft.trim().length === 0}
                      className="rounded-pill bg-(--color-accent) px-3 py-1 text-sm font-semibold text-(--color-on-accent) disabled:opacity-50"
                    >
                      Reply
                    </button>
                    <button
                      type="button"
                      onClick={() => setReplyingTo(null)}
                      className="text-sm font-semibold text-(--color-text-secondary)"
                    >
                      Cancel
                    </button>
                  </span>
                </form>
              )}

              {replies.length > 0 && (
                <ul className="flex flex-col gap-4">
                  {replies.map((reply) => renderComment(reply, true))}
                </ul>
              )}
            </li>
          ))}
        </ul>
      )}

      <form onSubmit={handleSubmit} className="flex flex-col gap-2">
        <textarea
          value={body}
          onChange={(event) => setBody(event.target.value)}
          placeholder="Add a comment"
          rows={2}
          className="resize-none rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
        />
        {error && <p className="text-sm text-red-500">{error}</p>}
        <button
          type="submit"
          disabled={submitting || body.trim().length === 0}
          className="self-start rounded-pill bg-(--color-accent) px-4 py-2 text-sm font-semibold text-(--color-on-accent) disabled:opacity-50"
        >
          {submitting ? "Posting…" : "Post"}
        </button>
      </form>
    </section>
  );
}
