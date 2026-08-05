"use client";

import { useState, useTransition } from "react";
import { likePost, unlikePost } from "@/lib/likes";
import { createClient } from "@/lib/supabase/client";

interface LikeButtonProps {
  postId: string;
  userId: string;
  initialCount: number;
  initialLiked: boolean;
}

/**
 * Optimistic on both directions, unlike FollowButton.
 *
 * Following someone has an outcome the client can't predict — a private
 * account turns a follow into a pending request — so that button waits for
 * the server. A like has exactly one possible result, so making the user
 * wait for a round trip before the heart fills would be latency for no
 * information. On failure it reverts.
 */
export function LikeButton({ postId, userId, initialCount, initialLiked }: LikeButtonProps) {
  const [liked, setLiked] = useState(initialLiked);
  const [count, setCount] = useState(initialCount);
  const [isPending, startTransition] = useTransition();

  function handleClick() {
    const wasLiked = liked;
    const previousCount = count;

    setLiked(!wasLiked);
    setCount(wasLiked ? Math.max(0, previousCount - 1) : previousCount + 1);

    startTransition(async () => {
      try {
        const supabase = createClient();
        if (wasLiked) {
          await unlikePost(supabase, postId, userId);
        } else {
          await likePost(supabase, postId, userId);
        }
      } catch {
        setLiked(wasLiked);
        setCount(previousCount);
      }
    });
  }

  return (
    <button
      type="button"
      onClick={handleClick}
      disabled={isPending}
      aria-pressed={liked}
      aria-label={liked ? "Unlike this post" : "Like this post"}
      className="flex items-center gap-1.5 text-sm text-(--color-text-secondary) disabled:opacity-60"
    >
      <span aria-hidden="true" className={liked ? "text-(--color-accent)" : ""}>
        {liked ? "♥" : "♡"}
      </span>
      {count > 0 && <span className="tabular-nums">{count}</span>}
    </button>
  );
}
