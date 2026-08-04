"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { CandidateList } from "@/components/CandidateList";
import { RatingChips } from "@/components/RatingChips";
import type { MediaCandidate } from "@/lib/catalog/types";
import {
  createPost,
  isRateLimited,
  ratingToPost,
  upsertMedia,
  type RatingChoice
} from "@/lib/compose";
import type { MediaKind } from "@/lib/media";
import { sanitizeCaption } from "@/lib/sanitize";
import { createClient } from "@/lib/supabase/client";

const KINDS: { kind: MediaKind; label: string }[] = [
  { kind: "movie", label: "Movies" },
  { kind: "show", label: "Shows" },
  { kind: "book", label: "Books" },
  { kind: "album", label: "Albums" }
];

const SEARCH_DEBOUNCE_MS = 350;

/**
 * The log flow, porting ComposerViewModel: search a catalog, pick something,
 * then either save it for later or rate and caption it.
 */
export function Composer({ userId }: { userId: string }) {
  const router = useRouter();
  const [kind, setKind] = useState<MediaKind>("movie");
  const [query, setQuery] = useState("");
  const [candidates, setCandidates] = useState<MediaCandidate[]>([]);
  const [searching, setSearching] = useState(false);
  const [picked, setPicked] = useState<MediaCandidate | null>(null);
  const [rating, setRating] = useState<RatingChoice | null>(null);
  const [caption, setCaption] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const trimmedQuery = query.trim();
  // Derived, not stored: an empty query means "show nothing" regardless of
  // what the last search returned. Clearing this from inside the effect
  // would be a synchronous setState in an effect body, which React 19's
  // set-state-in-effect rule rejects.
  const visibleCandidates = trimmedQuery.length === 0 ? [] : candidates;

  // The effect owns only the debounced fetch; it writes state from the
  // timer callback, never synchronously in the body.
  useEffect(() => {
    const trimmed = query.trim();
    if (trimmed.length === 0) return;

    const timer = setTimeout(async () => {
      setSearching(true);
      try {
        const response = await fetch(
          `/api/catalog/search?kind=${kind}&q=${encodeURIComponent(trimmed)}`
        );
        const json = await response.json();
        if (!response.ok) throw new Error(json.error ?? "Search failed.");
        setCandidates(json.candidates ?? []);
        setError("");
      } catch (searchError) {
        setCandidates([]);
        setError(searchError instanceof Error ? searchError.message : "Search failed.");
      } finally {
        setSearching(false);
      }
    }, SEARCH_DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [query, kind]);

  async function submit(action: "log" | "watchlist") {
    if (!picked) return;
    setError("");

    let captionValue: string | null = null;
    if (action === "log" && caption.trim().length > 0) {
      const result = sanitizeCaption(caption);
      if (!result.valid) {
        setError("Captions max out at 500 characters.");
        return;
      }
      captionValue = result.value;
    }

    const { action: postAction, rating: numericRating } =
      action === "watchlist" ? { action: "saved" as const, rating: null } : ratingToPost(rating);

    setSubmitting(true);
    try {
      const supabase = createClient();
      const mediaId = await upsertMedia(supabase, picked);
      await createPost(supabase, {
        authorId: userId,
        mediaId,
        action: postAction,
        rating: numericRating,
        caption: captionValue
      });
      router.push("/feed");
      router.refresh();
    } catch (submitError) {
      setError(
        isRateLimited(submitError)
          ? "You're logging very fast — give it a moment."
          : "Couldn't save that. Please try again."
      );
    } finally {
      setSubmitting(false);
    }
  }

  if (picked) {
    return (
      <div className="flex flex-col gap-4">
        <button
          type="button"
          onClick={() => setPicked(null)}
          className="self-start text-sm font-semibold text-(--color-text-secondary)"
        >
          ← Pick something else
        </button>

        <h1 className="text-xl font-semibold text-(--color-text-primary)">{picked.title}</h1>

        <RatingChips value={rating} onChange={setRating} />

        <textarea
          value={caption}
          onChange={(event) => setCaption(event.target.value)}
          placeholder="Add a note (optional)"
          rows={3}
          className="resize-none rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
        />

        {error && <p className="text-sm text-red-500">{error}</p>}

        <div className="flex gap-3">
          <button
            type="button"
            disabled={submitting}
            onClick={() => void submit("log")}
            className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
          >
            {submitting ? "Saving…" : "Log it"}
          </button>
          <button
            type="button"
            disabled={submitting}
            onClick={() => void submit("watchlist")}
            className="rounded-pill border border-(--color-separator) px-4 py-2 font-semibold text-(--color-text-primary) disabled:opacity-50"
          >
            Add to watchlist
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Log something</h1>

      <div className="flex gap-2">
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
        placeholder="Search"
        className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
      />

      {error && <p className="text-sm text-red-500">{error}</p>}

      {searching && visibleCandidates.length === 0 && (
        <p className="text-(--color-text-secondary)">Searching…</p>
      )}

      {!searching && trimmedQuery.length > 0 && visibleCandidates.length === 0 && !error && (
        <p className="text-(--color-text-secondary)">Nothing found for that.</p>
      )}

      <CandidateList candidates={visibleCandidates} onPick={setPicked} />
    </div>
  );
}
