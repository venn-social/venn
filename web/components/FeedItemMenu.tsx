"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { BookmarkIcon, CheckIcon } from "@/components/Icon";
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
        // The rating owns the right-hand corner now, and the artwork
        // already carries a scrim for these to sit on.
        align="left"
        presentation="icons"
        actions={[
          {
            label: "Log",
            // The same two glyphs the media page uses for the same two
            // shelves — a tick for what you have taken in, a bookmark for
            // what you mean to.
            icon: <CheckIcon size={17} />,
            onSelect: () =>
              void run(
                () => logFromFeed(createClient(), { authorId: viewerId, mediaId }),
                "Added to your collection"
              )
          },
          {
            label: "Add to Watchlist",
            icon: <BookmarkIcon size={17} />,
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
        //
        // Absolute, because the artwork's scrim is pinned to the bottom of
        // this container — a message in the flow would grow the container
        // and drag the scrim off the picture with it.
        <p
          role="status"
          className="absolute left-2 top-9 z-10 max-w-[70%] text-xs text-white drop-shadow-[0_1px_3px_rgb(0_0_0/0.7)]"
        >
          {done}
        </p>
      )}
    </>
  );
}
