"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { BookmarkIcon, CheckIcon, StarIcon } from "@/components/Icon";
import { addToHall, removeFromHall, type MediaStanding } from "@/lib/hallOfFame";
import { logFromFeed, removeFromLibrary, saveToWatchlist } from "@/lib/library";
import { createClient } from "@/lib/supabase/client";

interface MediaActionsProps {
  userId: string;
  mediaId: string;
  /** Where this title already sits for this person. Null means untouched. */
  initialStanding: MediaStanding | null;
}

type Slot = "log" | "watchlist" | "profile";

/**
 * Log it, save it, or put it on your profile — and see which you already
 * have.
 *
 * This replaced a single "Log this" button that told you nothing about what
 * you had already done with the title. You could log the same thing twice
 * over without the page ever mentioning it. Three controls, each lit when
 * it applies, answer "have I seen this?" before you touch anything.
 *
 * Collection and watchlist are exclusive — you cannot both have seen
 * something and be meaning to. Moving between them asks first, because it
 * throws away the other state, and moving to the watchlist also drops the
 * title out of your profile (the database refuses to keep an unwatched
 * thing in a hall of things you loved). The profile is additive on top of a
 * log, so putting something there when it is already logged asks nothing.
 */
export function MediaActions({ userId, mediaId, initialStanding }: MediaActionsProps) {
  const router = useRouter();
  const [standing, setStanding] = useState(initialStanding);
  const [confirming, setConfirming] = useState<Slot | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  const inCollection = standing !== null && standing.action !== "saved";
  const onWatchlist = standing?.action === "saved";
  const inProfile = standing?.hallPosition != null;

  /** What tapping `slot` would take away, if anything. */
  function displaces(slot: Slot): string | null {
    if (slot === "watchlist" && inCollection) {
      return inProfile
        ? "This is in your collection and on your profile. Move it to your watchlist?"
        : "This is in your collection. Move it to your watchlist?";
    }
    if ((slot === "log" || slot === "profile") && onWatchlist) {
      return "This is on your watchlist. Move it to your collection?";
    }
    return null;
  }

  async function apply(slot: Slot) {
    const client = createClient();
    setBusy(true);
    setError("");
    try {
      if (slot === "watchlist") {
        if (onWatchlist) {
          await removeFromLibrary(client, standing!.postId);
          setStanding(null);
        } else {
          if (standing) await removeFromLibrary(client, standing.postId);
          await saveToWatchlist(client, { authorId: userId, mediaId });
          setStanding({ postId: "", action: "saved", hallPosition: null });
        }
      } else if (slot === "log") {
        if (inCollection) {
          await removeFromLibrary(client, standing!.postId);
          setStanding(null);
        } else {
          await logFromFeed(client, { authorId: userId, mediaId });
          setStanding({ postId: "", action: "logged", hallPosition: null });
        }
      } else if (inProfile) {
        await removeFromHall(client, { authorId: userId, mediaId });
        setStanding({ ...standing!, hallPosition: null });
      } else {
        const result = await addToHall(client, { authorId: userId, mediaId, standing });
        if (result.full) {
          setError("Your profile already holds twelve. Take one out to add this.");
          return;
        }
        setStanding({ postId: standing?.postId ?? "", action: "rated", hallPosition: 1 });
      }
      // The server rendered this page's standing; re-read it rather than
      // trusting the optimistic shape, which does not know its own post id.
      router.refresh();
    } catch {
      setError("Couldn't save that. Please try again.");
    } finally {
      setBusy(false);
      setConfirming(null);
    }
  }

  function press(slot: Slot) {
    if (displaces(slot)) {
      setConfirming(slot);
      return;
    }
    void apply(slot);
  }

  return (
    <div className="flex flex-col items-end gap-2">
      <div className="flex items-center gap-1">
        <Control
          label={inCollection ? "Logged" : "Log this"}
          active={inCollection}
          disabled={busy}
          onClick={() => press("log")}
        >
          <CheckIcon size={18} />
        </Control>
        <Control
          label={onWatchlist ? "On your watchlist" : "Add to watchlist"}
          active={onWatchlist}
          disabled={busy}
          onClick={() => press("watchlist")}
        >
          <BookmarkIcon size={18} filled={onWatchlist} />
        </Control>
        <Control
          label={inProfile ? "On your profile" : "Add to your profile"}
          active={inProfile}
          disabled={busy}
          onClick={() => press("profile")}
        >
          <StarIcon size={18} filled={inProfile} />
        </Control>
      </div>

      {confirming && (
        <div
          role="alertdialog"
          aria-label="Move this title"
          className="flex max-w-xs flex-col items-end gap-2 rounded-md border border-(--color-separator) bg-(--color-background) p-3 text-right shadow-lg"
        >
          <p className="text-sm text-(--color-text-primary)">{displaces(confirming)}</p>
          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={() => void apply(confirming)}
              className="text-sm font-semibold text-(--color-accent)"
            >
              Move
            </button>
            <button
              type="button"
              onClick={() => setConfirming(null)}
              className="text-sm text-(--color-text-secondary)"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      {error && <p className="max-w-xs text-right text-sm text-red-500">{error}</p>}
    </div>
  );
}

function Control({
  label,
  active,
  disabled,
  onClick,
  children
}: {
  label: string;
  active: boolean;
  disabled: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-pressed={active}
      aria-label={label}
      title={label}
      className={
        active
          ? "flex h-9 w-9 items-center justify-center rounded-pill bg-(--color-accent) text-(--color-on-accent) disabled:opacity-50"
          : "flex h-9 w-9 items-center justify-center rounded-pill border border-(--color-separator) text-(--color-text-secondary) transition-colors hover:text-(--color-text-primary) disabled:opacity-50"
      }
    >
      {children}
    </button>
  );
}
