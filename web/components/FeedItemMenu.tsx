"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { MediaOverflowMenu } from "@/components/MediaOverflowMenu";
import { logFromFeed, saveToWatchlist } from "@/lib/library";
import { createClient } from "@/lib/supabase/client";

interface FeedItemMenuProps {
  mediaId: string;
  mediaTitle: string;
  /**
   * The signed-in user. FeedRow only mounts this when there is one and it
   * is not the post's own author, so it is non-null here.
   */
  viewerId: string;
}

/**
 * Log or save something you spotted on someone else's feed, without
 * searching for it again in the composer — the item is right there, and
 * making people re-find it was the friction worth removing.
 */
export function FeedItemMenu({ mediaId, mediaTitle, viewerId }: FeedItemMenuProps) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<string | null>(null);

  async function run(work: () => Promise<void>, confirmation: string) {
    setBusy(true);
    try {
      await work();
      setDone(confirmation);
      router.refresh();
    } catch {
      setDone("Didn't work — try again.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <MediaOverflowMenu
        label={`Options for ${mediaTitle}`}
        busy={busy}
        actions={[
          {
            label: "Log",
            onSelect: () =>
              void run(
                () => logFromFeed(createClient(), { authorId: viewerId, mediaId }),
                "Added to your collection"
              )
          },
          {
            label: "Add to Watchlist",
            onSelect: () =>
              void run(
                () => saveToWatchlist(createClient(), { authorId: viewerId, mediaId }),
                "Added to your watchlist"
              )
          }
        ]}
      />

      {done && (
        // Announced rather than just shown: the only visible change is on a
        // page the user is not looking at.
        <p role="status" className="pt-1 text-xs text-(--color-text-secondary)">
          {done}
        </p>
      )}
    </>
  );
}
