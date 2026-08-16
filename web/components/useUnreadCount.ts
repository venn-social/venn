"use client";

import { useEffect, useState } from "react";
import { fetchUnreadCount } from "@/lib/notifications";
import { createClient } from "@/lib/supabase/client";

/**
 * The unread badge, kept live.
 *
 * The layout renders a count on the server, which is correct at the moment
 * the page is built and stale from then on — a notification arriving while
 * someone reads their feed went unannounced until they navigated. The whole
 * point of a badge is to be right before you go looking.
 *
 * Re-reads the count on any change rather than trying to add and subtract
 * locally. One round trip per event is cheap, and it means a notification
 * marked read in another tab lands here correctly too, which incrementing a
 * local number cannot do.
 *
 * No filter on the subscription: Realtime applies RLS to `postgres_changes`,
 * and `notifications_select_own` already scopes rows to the recipient, so
 * this can only ever be delivered the reader's own rows.
 */
export function useUnreadCount(initial: number): number {
  const [count, setCount] = useState(initial);
  const [lastFromServer, setLastFromServer] = useState(initial);

  // The server's number is authoritative on navigation; without this the
  // badge would keep whatever the first render happened to see. Adjusted
  // during render rather than in an effect — React 19 rejects mirroring a
  // prop into state from an effect, and this is the documented alternative.
  if (lastFromServer !== initial) {
    setLastFromServer(initial);
    setCount(initial);
  }

  useEffect(() => {
    const client = createClient();
    const channel = client
      .channel("notifications-badge")
      .on(
        "postgres_changes",
        { event: "*", schema: "public", table: "notifications" },
        () => {
          void fetchUnreadCount(client)
            .then(setCount)
            .catch(() => {
              // Leave the last known number. A failed re-read should not
              // blank a badge that was correct a second ago.
            });
        }
      )
      .subscribe();

    return () => {
      void client.removeChannel(channel);
    };
  }, []);

  return count;
}
