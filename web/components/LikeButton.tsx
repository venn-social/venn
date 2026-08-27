"use client";

import { useState, useTransition } from "react";
import { HeartIcon } from "@/components/Icon";
import { likePost, unlikePost } from "@/lib/likes";
import { createClient } from "@/lib/supabase/client";

interface LikeButtonProps {
  postId: string;
  userId: string;
  initialCount: number;
  initialLiked: boolean;
  /** Glyph size in px. Smaller on a cover than under a post. */
  size?: number;
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
export function LikeButton({ postId, userId, initialCount, initialLiked, size }: LikeButtonProps) {
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
      // Type size is inherited rather than set here: the same button is
      // rendered at body size under a post and at caption size on a cover,
      // and the tally has to match the line it sits on either way.
      className="flex items-center gap-1.5 text-(--color-text-secondary) transition-colors hover:text-(--color-text-primary) disabled:opacity-60"
    >
      <HeartIcon size={size} filled={liked} className={liked ? "text-(--color-like)" : ""} />
      {count > 0 && <span className="tabular-nums">{count}</span>}
    </button>
  );
}
