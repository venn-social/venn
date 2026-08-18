"use client";

import { useState } from "react";
import { CommentThread } from "@/components/CommentThread";
import { CommentIcon } from "@/components/Icon";
import { LikeButton } from "@/components/LikeButton";
import { fetchComments, type PostComment } from "@/lib/comments";
import { createClient } from "@/lib/supabase/client";

interface PostActionsProps {
  postId: string;
  userId: string;
  /** The post's author — they can delete any comment on their own post. */
  postAuthorId: string;
  likeCount: number;
  likedByMe: boolean;
  commentCount: number;
}

/**
 * The social footer under a feed row: like, and comments that open in
 * place.
 *
 * Commenting used to mean leaving the feed for the post's permalink and
 * then coming back, which loses your scroll position and turns a reply into
 * a trip. Every feed people actually use expands the thread under the post
 * instead, so this does too.
 *
 * Comments load on first expand rather than with the feed. A feed page
 * holds many posts and most of their threads are never opened; fetching
 * them all up front would be the larger part of the page's cost, spent
 * mostly on things nobody reads. The permalink at /post/[id] still exists
 * and still server-renders its comments — notifications link straight to
 * it, and it is the only shareable address a conversation has.
 */
export function PostActions({
  postId,
  userId,
  postAuthorId,
  likeCount,
  likedByMe,
  commentCount
}: PostActionsProps) {
  const [expanded, setExpanded] = useState(false);
  const [comments, setComments] = useState<PostComment[] | null>(null);
  const [loading, setLoading] = useState(false);
  const [failed, setFailed] = useState(false);

  async function toggle() {
    const next = !expanded;
    setExpanded(next);
    if (!next || comments !== null || loading) return;

    setLoading(true);
    setFailed(false);
    try {
      setComments(await fetchComments(createClient(), postId));
    } catch {
      // Say so rather than showing an empty thread, which would read as
      // "no comments" — a different and wrong answer.
      setFailed(true);
    } finally {
      setLoading(false);
    }
  }

  // Once loaded, trust what we fetched over the count the page was built
  // with: the two disagree as soon as anyone comments.
  const shown = comments?.length ?? commentCount;

  return (
    <div className="flex flex-col gap-3">
      <div className="flex items-center gap-4">
        <LikeButton
          postId={postId}
          userId={userId}
          initialCount={likeCount}
          initialLiked={likedByMe}
        />
        <button
          type="button"
          onClick={() => void toggle()}
          aria-expanded={expanded}
          aria-controls={`comments-${postId}`}
          className="flex items-center gap-1.5 text-sm text-(--color-text-secondary)"
        >
          <CommentIcon />
          <span>
            {shown > 0 ? shown : ""}{" "}
            <span className={shown > 0 ? "sr-only" : ""}>
              {shown === 1 ? "comment" : "comments"}
            </span>
          </span>
        </button>
      </div>

      {expanded && (
        <div id={`comments-${postId}`} className="border-t border-(--color-separator) pt-3">
          {loading && <p className="text-sm text-(--color-text-secondary)">Loading comments…</p>}
          {failed && (
            <p className="text-sm text-(--color-text-secondary)">
              Couldn&apos;t load the comments. Try again.
            </p>
          )}
          {comments !== null && (
            <CommentThread
              postId={postId}
              userId={userId}
              postAuthorId={postAuthorId}
              initialComments={comments}
            />
          )}
        </div>
      )}
    </div>
  );
}
