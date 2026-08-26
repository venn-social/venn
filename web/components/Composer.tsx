"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { AddToListPicker } from "@/components/AddToListPicker";
import { CandidateList } from "@/components/CandidateList";
import { ChevronLeftIcon, StarIcon } from "@/components/Icon";
import { searchKindsFor, type ExploreCategory } from "@/components/CategoryChips";
import { SearchPanel } from "@/components/SearchPanel";
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
import { addToHall } from "@/lib/hallOfFame";
import { createClient } from "@/lib/supabase/client";

/** The tab that owns a kind, for callers that arrive with one already. */
function categoryForKind(kind: MediaKind): ExploreCategory {
  switch (kind) {
    case "movie":
      return "movies";
    case "show":
      return "tv";
    case "album":
      return "music";
    default:
      return "books";
  }
}

const SEARCH_DEBOUNCE_MS = 350;

/**
 * The log flow, porting ComposerViewModel: search a catalog, pick something,
 * then either save it for later or rate and caption it.
 */
export function Composer({
  userId,
  initialKind = "movie",
  initialQuery = "",
  initialPicked = null,
  onDone
}: {
  userId: string;
  initialKind?: MediaKind;
  initialQuery?: string;
  /** Opened for a title that is already decided — skips straight to the form. */
  initialPicked?: MediaCandidate | null;
  /** Called when the composer has finished its job, so a host can close it. */
  onDone?: () => void;
}) {
  const router = useRouter();
  // Read once as initial state rather than synced: Explorer links here with
  // a prefill, but after that the composer owns its own state.
  const [category, setCategory] = useState<ExploreCategory>(categoryForKind(initialKind));
  const [query, setQuery] = useState(initialQuery);
  const [candidates, setCandidates] = useState<MediaCandidate[]>([]);
  const [searching, setSearching] = useState(false);
  const [picked, setPicked] = useState<MediaCandidate | null>(initialPicked);
  const [rating, setRating] = useState<RatingChoice | null>(null);
  const [caption, setCaption] = useState("");
  /** Put it on the profile as well as in the collection. */
  const [starred, setStarred] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  // Set once something is logged — the media row now exists, so it can go
  // straight into a list without another catalog round trip.
  const [logged, setLogged] = useState<{ mediaId: string; action: "log" | "watchlist" } | null>(
    null
  );

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
        // "All" covers four kinds, so this is one request each rather than
        // one request — the same shape Explorer uses for the same tabs.
        const kinds = searchKindsFor(category);
        const responses = await Promise.all(
          kinds.map(async (mediaKind) => {
            const response = await fetch(
              `/api/catalog/search?kind=${mediaKind}&q=${encodeURIComponent(trimmed)}`
            );
            const json = await response.json();
            if (!response.ok) throw new Error(json.error ?? "Search failed.");
            return (json.candidates ?? []) as MediaCandidate[];
          })
        );
        setCandidates(responses.flat());
        setError("");
      } catch (searchError) {
        setCandidates([]);
        setError(searchError instanceof Error ? searchError.message : "Search failed.");
      } finally {
        setSearching(false);
      }
    }, SEARCH_DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [query, category]);

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
      // Stay put and offer the list step rather than bouncing to the
      // feed: logging and listing are the same thought, and sending the
      // user away makes them navigate back to finish it.
      // Starring is a second write rather than a column on the first: the
      // free slot has to be found, and the hall can be full, which is a
      // thing to say rather than a thing to fail on.
      if (starred && action === "log") {
        const placed = await addToHall(supabase, {
          authorId: userId,
          mediaId,
          standing: { postId: "", action: postAction, hallPosition: null }
        });
        if (placed.full) {
          setError("Logged, but your profile already holds twelve — take one out to add this.");
        }
      }

      setLogged({ mediaId, action });
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

  if (logged && picked) {
    return (
      <div className="flex flex-col gap-4">
        <div className="flex flex-col gap-1">
          <h1 className="text-xl font-semibold text-(--color-text-primary)">
            {logged.action === "watchlist" ? "Saved" : "Logged"}
          </h1>
          <p className="text-(--color-text-secondary)">{picked.title}</p>
        </div>

        {/* The log succeeded and the star did not, which is a caveat rather
            than a failure — so it belongs here, on the confirmation, not on
            the form that has already been left behind. */}
        {error && <p className="text-sm text-red-500">{error}</p>}

        <AddToListPicker userId={userId} mediaId={logged.mediaId} />

        <div className="flex gap-3">
          <button
            type="button"
            // In a sheet, Done means "put this away and give me back the
            // page I was on". Only the standalone route has nowhere to
            // return to, and there the feed is the right destination.
            onClick={() => (onDone ? onDone() : router.push("/feed"))}
            className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent)"
          >
            Done
          </button>
          <button
            type="button"
            onClick={() => {
              // Back to a clean search for the next thing.
              setLogged(null);
              setPicked(null);
              setRating(null);
              setCaption("");
              setQuery("");
            }}
            className="px-2 py-2 font-semibold text-(--color-text-secondary) hover:text-(--color-text-primary)"
          >
            Log another
          </button>
        </div>
      </div>
    );
  }

  if (picked) {
    return (
      <div className="flex flex-col gap-4">
        <button
          type="button"
          onClick={() => setPicked(null)}
          aria-label="Back"
          className="-ml-1.5 self-start rounded-pill p-1.5 text-(--color-text-secondary) hover:text-(--color-text-primary)"
        >
          <ChevronLeftIcon size={20} />
        </button>

        <h1 className="text-xl font-semibold text-(--color-text-primary)">{picked.title}</h1>

        <div className="flex items-center gap-3">
          <RatingChips value={rating} onChange={setRating} />

          {/* Starring is a statement about you, not about the thing, so it
              sits apart from the sentiments rather than among them. It
              applies to Log only: the database refuses to keep something
              you have not got to yet in a hall of things you loved, so
              Watchlist ignores it. */}
          <button
            type="button"
            aria-pressed={starred}
            aria-label={starred ? "On your profile" : "Add to your profile"}
            title={starred ? "On your profile" : "Add to your profile"}
            onClick={() => setStarred((was) => !was)}
            className={
              starred
                ? "ml-auto flex h-11 w-11 items-center justify-center rounded-pill bg-(--color-accent) text-(--color-on-accent)"
                : "ml-auto flex h-11 w-11 items-center justify-center rounded-pill border border-(--color-separator) text-(--color-text-secondary) hover:text-(--color-text-primary)"
            }
          >
            <StarIcon size={18} filled={starred} />
          </button>
        </div>

        <textarea
          value={caption}
          onChange={(event) => setCaption(event.target.value)}
          placeholder="Add a note"
          rows={2}
          className="resize-none border-b border-(--color-separator) bg-transparent py-2 text-(--color-text-primary) outline-none placeholder:text-(--color-text-secondary) focus:border-(--color-text-secondary)"
        />

        {error && <p className="text-sm text-red-500">{error}</p>}

        <div className="flex gap-3">
          <button
            type="button"
            disabled={submitting}
            onClick={() => void submit("log")}
            className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
          >
            {submitting ? "Saving…" : "Log"}
          </button>
          <button
            type="button"
            disabled={submitting}
            onClick={() => void submit("watchlist")}
            className="px-2 py-2 font-semibold text-(--color-text-secondary) hover:text-(--color-text-primary) disabled:opacity-50"
          >
            Watchlist
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <SearchPanel
        category={category}
        onCategoryChange={setCategory}
        query={query}
        onQueryChange={setQuery}
        placeholder="Search for anything"
        // No "people" tab: you cannot log a person, and the tab would lead
        // somewhere with nothing to do.
        exclude={["people"]}
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
