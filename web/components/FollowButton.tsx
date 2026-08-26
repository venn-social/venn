"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { createClient } from "@/lib/supabase/client";
import { requestFollow, unfollow, type FollowStatus } from "@/lib/follow";

type ButtonState = "notFollowing" | "requested" | "following";

function toButtonState(status: FollowStatus | null): ButtonState {
  if (status === "accepted") return "following";
  if (status === "pending") return "requested";
  return "notFollowing";
}

interface FollowButtonProps {
  followerId: string;
  followeeId: string;
  initialStatus: FollowStatus | null;
}

export function FollowButton({ followerId, followeeId, initialStatus }: FollowButtonProps) {
  const router = useRouter();
  const [state, setState] = useState<ButtonState>(toButtonState(initialStatus));
  const [isPending, startTransition] = useTransition();

  function handleClick() {
    const supabase = createClient();

    if (state === "following" || state === "requested") {
      const previous = state;
      setState("notFollowing");
      startTransition(async () => {
        try {
          await unfollow(supabase, followerId, followeeId);
          // The header's follower count and the shelves/overlap gating are
          // server-rendered, so they'd otherwise show pre-unfollow numbers
          // until a manual reload. Mirrors iOS's refreshFollowCounts().
          router.refresh();
        } catch {
          setState(previous);
        }
      });
      return;
    }

    startTransition(async () => {
      try {
        const status = await requestFollow(supabase, followeeId);
        setState(toButtonState(status));
        if (status === "accepted") router.refresh();
      } catch {
        setState("notFollowing");
      }
    });
  }

  const label =
    state === "following" ? "Following" : state === "requested" ? "Requested" : "Follow";
  const isPrimary = state === "notFollowing";

  return (
    <button
      type="button"
      onClick={handleClick}
      disabled={isPending}
      // A hairline on the page's own ground either way. The accent fill
      // made Follow the loudest thing on someone's profile, above the
      // person and above what they like, which is not the order of
      // importance. The two states differ by weight of text, not by a
      // block of colour.
      className={[
        "rounded-pill border border-(--color-separator) bg-(--color-background)",
        "px-4 py-1.5 text-sm transition-colors disabled:opacity-50",
        isPrimary
          ? "font-semibold text-(--color-text-primary) hover:border-(--color-text-secondary)"
          : "text-(--color-text-secondary) hover:text-(--color-text-primary)"
      ].join(" ")}
    >
      {label}
    </button>
  );
}
