"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CandidateList } from "@/components/CandidateList";
import type { MediaCandidate } from "@/lib/catalog/types";
import { upsertMedia } from "@/lib/compose";
import { addToList } from "@/lib/lists";
import type { MediaKind } from "@/lib/media";
import { createClient } from "@/lib/supabase/client";

const KINDS: { kind: MediaKind; label: string }[] = [
  { kind: "movie", label: "Movies" },
  { kind: "show", label: "Shows" },
  { kind: "book", label: "Books" },
  { kind: "album", label: "Albums" }
];

const SEARCH_DEBOUNCE_MS = 350;

interface AddToListProps {
  listId: string;
  /** Where the next item goes — the end of the list. */
  nextPosition: number;
}

/**
 * Search the catalog and append the result to this list.
 *
 * Note the two-step write: `list_items.media_id` references `public.media`,
 * so a catalog result that nobody has logged yet doesn't exist as a row
 * anywhere. It has to be upserted into `media` first — the same
 * select-then-insert the composer uses — before it can be listed. Without
 * that, adding an unlogged film to a list fails on a foreign key.
 */
export function AddToList({ listId, nextPosition }: AddToListProps) {
  const router = useRouter();
  const [kind, setKind] = useState<MediaKind>("movie");
  const [query, setQuery] = useState("");
  const [candidates, setCandidates] = useState<MediaCandidate[]>([]);
  const [searching, setSearching] = useState(false);
  const [adding, setAdding] = useState(false);
  const [error, setError] = useState("");

  const trimmed = query.trim();
  // Derived rather than cleared from the effect — React 19's
  // set-state-in-effect rule rejects the synchronous version.
  const visible = trimmed.length === 0 ? [] : candidates;

  useEffect(() => {
    const term = query.trim();
    if (term.length === 0) return;

    const timer = setTimeout(async () => {
      setSearching(true);
      try {
        const response = await fetch(
          `/api/catalog/search?kind=${kind}&q=${encodeURIComponent(term)}`
        );
        const json = await response.json();
        if (!response.ok) throw new Error(json.error ?? "Search failed.");
        setCandidates(json.candidates ?? []);
        setError("");
      } catch {
        setCandidates([]);
        setError("Search failed.");
      } finally {
        setSearching(false);
      }
    }, SEARCH_DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [query, kind]);

  async function handlePick(candidate: MediaCandidate) {
    setAdding(true);
    setError("");
    try {
      const supabase = createClient();
      // The catalog result may not exist in public.media yet.
      const mediaId = await upsertMedia(supabase, candidate);
      await addToList(supabase, listId, mediaId, nextPosition);
      setQuery("");
      setCandidates([]);
      router.refresh();
    } catch {
      setError("Couldn't add that. Please try again.");
    } finally {
      setAdding(false);
    }
  }

  return (
    <section className="flex flex-col gap-3">
      <h2 className="font-semibold text-(--color-text-primary)">Add something</h2>

      <div className="flex flex-wrap gap-2">
        {KINDS.map((option) => (
          <button
            key={option.kind}
            type="button"
            aria-pressed={kind === option.kind}
            onClick={() => setKind(option.kind)}
            className={
              kind === option.kind
                ? "rounded-pill bg-(--color-accent) px-3 py-1.5 text-sm font-semibold text-(--color-on-accent)"
                : "rounded-pill border border-(--color-separator) px-3 py-1.5 text-sm text-(--color-text-primary)"
            }
          >
            {option.label}
          </button>
        ))}
      </div>

      <input
        type="text"
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="Search to add"
        disabled={adding}
        className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none disabled:opacity-60"
      />

      {error && <p className="text-sm text-red-500">{error}</p>}
      {adding && <p className="text-(--color-text-secondary)">Adding…</p>}
      {searching && visible.length === 0 && (
        <p className="text-(--color-text-secondary)">Searching…</p>
      )}

      <CandidateList candidates={visible} onPick={(c) => void handlePick(c)} />
    </section>
  );
}
