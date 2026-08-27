"use client";

import { useState } from "react";
import { CommentThread } from "@/components/CommentThread";
import { FeedRow } from "@/components/FeedRow";
import { CommentIcon } from "@/components/Icon";
import { LikeButton } from "@/components/LikeButton";
import { fetchComments, type PostComment } from "@/lib/comments";
import type { FeedPost } from "@/lib/feed";
import { createClient } from "@/lib/supabase/client";

interface FeedPostCardProps {
  post: FeedPost;
  /** The signed-in user: they like, they comment, they see the artwork menu. */
  userId: string;
  likeCount: number;
  likedByMe: boolean;
  commentCount: number;
}

/**
 * A feed post with its social controls: like and comment laid over the
 * bottom of the artwork, and comments that open in place beneath it.
 *
 * This owns the whole card rather than being a slot inside one because the
 * controls and the thread they open now live in two different places — the
 * controls over the cover, the thread at the foot of the post — and one
 * component cannot render into two parents. The expanded state belongs to
 * whichever component spans both, so it belongs here.
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
export function FeedPostCard({
  post,
  userId,
  likeCount,
  likedByMe,
  commentCount
}: FeedPostCardProps) {
  const postId = post.id;
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
    <FeedRow
      post={post}
      viewerId={userId}
      overlay={
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
            // Built exactly like the like button beside it: the glyph, the
            // tally when there is one, and the words only where a screen
            // reader needs them. "0 comments" written out was the loudest
            // thing on a quiet post.
            aria-label={shown === 1 ? "1 comment" : `${shown} comments`}
            className="flex items-center gap-1.5 text-sm text-(--color-text-secondary) transition-colors hover:text-(--color-text-primary)"
          >
            <CommentIcon />
            {shown > 0 && <span className="tabular-nums">{shown}</span>}
          </button>
        </div>
      }
      actions={
        expanded ? (
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
                postAuthorId={post.author.id}
                initialComments={comments}
              />
            )}
          </div>
        ) : undefined
      }
    />
  );
}
