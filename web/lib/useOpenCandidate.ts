"use client";

import { useRouter } from "next/navigation";
import { useCallback, useState } from "react";
import type { MediaCandidate } from "@/lib/catalog/types";
import { upsertMedia } from "@/lib/compose";
import { createClient } from "@/lib/supabase/client";

/**
 * Opens a catalog result on its detail page.
 *
 * Tapping something in Explorer used to go to the composer prefilled with
 * the title, which re-ran the search you had just done and made you pick
 * the same item a second time before you could read anything about it. Two
 * taps and a wait to answer "what is this", which is the first question.
 *
 * A catalog result has no row in `public.media` yet and so no detail page
 * to open, which is why it went to the composer at all. Creating the row on
 * open fixes that with the code that already exists — `upsertMedia` is what
 * logging would call moments later anyway, and it is idempotent on
 * (source, external id), so opening the same title twice does not duplicate
 * it. The cost is catalog rows for things people looked at but never
 * logged; the detail page is worth more than that is worth avoiding.
 *
 * If the write fails we fall back to the composer — the old behaviour, and
 * still better than a dead tap.
 */
export function useOpenCandidate() {
  const router = useRouter();
  const [openingId, setOpeningId] = useState<string | null>(null);

  const open = useCallback(
    async (candidate: MediaCandidate) => {
      setOpeningId(candidate.id);
      try {
        const mediaId = await upsertMedia(createClient(), candidate);
        router.push(`/media/${mediaId}`);
      } catch {
        const params = new URLSearchParams({ kind: candidate.kind, q: candidate.title });
        router.push(`/composer?${params.toString()}`);
      } finally {
        setOpeningId(null);
      }
    },
    [router]
  );

  return { open, openingId };
}
