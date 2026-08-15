"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";

/**
 * Shown when the catalog provider could not be reached.
 *
 * iOS has offered a retry here since the screen was built; web silently
 * showed less, which reads as "this film has no cast" rather than "we
 * couldn't ask". Same page, same failure, two different stories.
 *
 * The retry is `router.refresh()`, which re-runs the Server Component and
 * re-attempts the provider call **in-process**. That matters: the obvious
 * alternative — a client island fetching from our own API — would mean
 * re-introducing the catalog detail route deleted in #177, re-opening an
 * endpoint that spends TMDB quota. Refreshing the server render gets the
 * same recovery with no new surface, and keeps the API key server-side
 * where it belongs.
 */
export function DetailUnavailable() {
  const router = useRouter();
  const [retrying, setRetrying] = useState(false);

  return (
    <section
      role="status"
      className="flex flex-col items-start gap-2 rounded-lg border border-(--color-separator) p-4"
    >
      <p className="text-(--color-text-secondary)">
        Couldn&apos;t load the extra details just now. Everything above is still correct.
      </p>
      <button
        type="button"
        disabled={retrying}
        onClick={() => {
          setRetrying(true);
          router.refresh();
          // The refresh replaces this component when it succeeds. If it
          // fails the page re-renders with this still here, so the button
          // has to become usable again rather than staying stuck.
          setTimeout(() => setRetrying(false), 2000);
        }}
        className="rounded-pill bg-(--color-accent) px-4 py-1.5 text-sm font-semibold text-(--color-on-accent) disabled:opacity-50"
      >
        {retrying ? "Trying…" : "Try again"}
      </button>
    </section>
  );
}
