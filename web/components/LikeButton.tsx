"use client";

import { useState, useTransition } from "react";
import { HeartIcon } from "@/components/Icon";
import { likePost, unlikePost } from "@/lib/likes";
import { createClient } from "@/lib/supabase/client";

interface LikeButtonProps {
  postId: string;
  userId: string;
  initialLiked: boolean;
  /** Glyph size in px. Smaller on a cover than under a post. */
  size?: number;
}

/**
 * A heart, and nothing else.
 *
 * The tally is gone deliberately. A count next to a like is a scoreboard,
 * and a scoreboard changes what people post; the one thing the button has
 * to say is whether *you* liked this, which the fill says on its own.
 *
 * Optimistic on both directions, unlike FollowButton.
 *
 * Following someone has an outcome the client can't predict — a private
 * account turns a follow into a pending request — so that button waits for
 * the server. A like has exactly one possible result, so making the user
 * wait for a round trip before the heart fills would be latency for no
 * information. On failure it reverts.
 */
export function LikeButton({ postId, userId, initialLiked, size }: LikeButtonProps) {
  const [liked, setLiked] = useState(initialLiked);
  const [isPending, startTransition] = useTransition();

  function handleClick() {
    const wasLiked = liked;
    setLiked(!wasLiked);

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
      className="flex items-center text-(--color-text-secondary) transition-colors hover:text-(--color-text-primary) disabled:opacity-60"
    >
      <HeartIcon size={size} filled={liked} className={liked ? "text-(--color-like)" : ""} />
    </button>
  );
}
