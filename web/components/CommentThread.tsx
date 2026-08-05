"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Avatar } from "@/components/Avatar";
import { addComment, deleteComment, type PostComment } from "@/lib/comments";
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
 * Deliberately flat — no reply threading. That needs a parent_id, a depth
 * cap, and a recursive read, none of which is worth building before anyone
 * has commented once.
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

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError("");

    // Comments share the caption validator — same 1-500 bound, and the
    // post_comments_body_length constraint is the final say.
    const result = sanitizeCaption(body);
    if (!result.valid) {
      setError(
        result.reason === "empty"
          ? "Write something first."
          : "Comments max out at 500 characters."
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
          {comments.map((comment) => {
            const name = comment.author.displayName ?? comment.author.username;
            // The RLS policy allows both; mirroring it here keeps the
            // button from appearing where the delete would be refused.
            const canDelete = userId === comment.author.id || userId === postAuthorId;

            return (
              <li key={comment.id} className="flex gap-3">
                <Avatar name={name} avatarUrl={comment.author.avatarUrl} size={32} />
                <div className="flex flex-1 flex-col gap-0.5">
                  <div className="flex items-baseline gap-2">
                    <span className="text-sm font-medium text-(--color-text-primary)">{name}</span>
                    <span className="text-xs text-(--color-text-secondary)">
                      {shortRelativeTime(comment.createdAt)}
                    </span>
                    {canDelete && (
                      <button
                        type="button"
                        onClick={() => void handleDelete(comment.id)}
                        className="ml-auto text-xs text-(--color-text-secondary) hover:text-red-500"
                      >
                        Delete
                      </button>
                    )}
                  </div>
                  <p className="text-(--color-text-primary)">{comment.body}</p>
                </div>
              </li>
            );
          })}
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
