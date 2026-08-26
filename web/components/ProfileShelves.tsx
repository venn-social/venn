"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { MediaCover } from "@/components/MediaCover";
import { MediaKindFilter, type KindFilter } from "@/components/MediaKindFilter";
import { MediaOverflowMenu } from "@/components/MediaOverflowMenu";
import { RatingChips } from "@/components/RatingChips";
import { ratingToPost, type RatingChoice } from "@/lib/compose";
import { reorderHall } from "@/lib/hallOfFame";
import {
  movedLibraryOrder,
  removeFromLibrary,
  reorderLibrary,
  updatePostRating,
  type LibraryItem
} from "@/lib/library";
import type { MediaKind } from "@/lib/media";
import { createClient } from "@/lib/supabase/client";

type Shelf = "hall" | "collection" | "watchlist";

interface ProfileShelvesProps {
  /**
   * The starred handful. Its tab only exists when it has something in it,
   * and when it does it is where the profile opens — a profile should lead
   * with what someone likes, and fall back to what they have seen only
   * when they have not said.
   */
  hall?: LibraryItem[];
  collection: LibraryItem[];
  watchlist: LibraryItem[];
  /**
   * Empty-state copy differs between your own profile and someone else's —
   * iOS says "Nothing in your collection yet." on ProfileView but
   * "Nothing logged yet." on PublicProfileView.
   */
  emptyCollection: string;
  emptyWatchlist: string;
  /** Only your own shelves get the remove control. */
  canEdit?: boolean;
}

const COLLECTION_TABS: { shelf: Shelf; label: string }[] = [
  { shelf: "collection", label: "Collection" },
  { shelf: "watchlist", label: "Watchlist" }
];

/**
 * Collection / Watchlist tabs above a three-column cover grid, porting
 * ShelfTabs.swift + ProfileShelfGallery.swift. Collection is everything
 * logged or rated; Watchlist is everything saved.
 *
 * The kind filter runs client-side: both shelves are already fetched in
 * full by the server component, so re-querying to narrow them would be a
 * round trip to discard rows we are holding.
 */
export function ProfileShelves({
  hall = [],
  collection,
  watchlist,
  emptyCollection,
  emptyWatchlist,
  canEdit = false
}: ProfileShelvesProps) {
  const router = useRouter();
  const tabs =
    hall.length > 0
      ? [{ shelf: "hall" as Shelf, label: "Starred" }, ...COLLECTION_TABS]
      : COLLECTION_TABS;
  // Starts on the hall when there is one. Read once rather than synced: if
  // the last star is removed while you are looking at it, falling back is
  // handled below rather than by resetting state from an effect, which
  // React 19's set-state-in-effect rule rejects.
  const [chosen, setChosen] = useState<Shelf | null>(null);
  const shelf: Shelf =
    chosen && (chosen !== "hall" || hall.length > 0)
      ? chosen
      : hall.length > 0
        ? "hall"
        : "collection";
  const setShelf = setChosen;
  const [kind, setKind] = useState<KindFilter>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  /** The item whose rating is being edited, if any. */
  const [editingId, setEditingId] = useState<string | null>(null);
  /**
   * The cover picked up for reordering, if any. Chosen from its own ⋯
   * menu rather than by dragging: a drag is invisible until you try it,
   * and on a grid of covers it competes with the tap that opens one.
   */
  const [movingId, setMovingId] = useState<string | null>(null);

  const items = shelf === "hall" ? hall : shelf === "collection" ? collection : watchlist;
  // The hall has no empty state: its tab only exists when it has items, so
  // there is no way to arrive at an empty one.
  const emptyMessage = shelf === "watchlist" ? emptyWatchlist : emptyCollection;

  useEffect(() => {
    if (!movingId) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setMovingId(null);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [movingId]);

  const available = useMemo(
    () => new Set<MediaKind>(items.map((item) => item.media.kind)),
    [items]
  );
  const visible = kind ? items.filter((item) => item.media.kind === kind) : items;

  // Reordering is only coherent over the whole shelf: moving something
  // inside a filtered view would write positions that ignore the hidden
  // items.
  const reorderable = canEdit && kind === null;
  const ordered = visible;

  /** Put the held cover where `toIndex` is, and write the new order. */
  function placeAt(toIndex: number) {
    if (!movingId) return;
    const order = movedLibraryOrder(ordered, movingId, toIndex);
    setMovingId(null);
    void handleReorder(order);
  }

  async function handleReorder(order: string[]) {
    try {
      // The hall is sorted by its own column, so it reorders through its
      // own function. Sending a hall order to reorderLibrary writes the
      // shelves' column instead, which reads as the drag being rejected.
      await (shelf === "hall" ? reorderHall : reorderLibrary)(createClient(), order);
      router.refresh();
    } catch {
      // The grid keeps the arrangement on screen; a refresh would snap it
      // back and look like the drag was rejected rather than unsaved.
    }
  }

  async function handleRemove(item: LibraryItem) {
    setBusyId(item.id);
    try {
      await removeFromLibrary(createClient(), item.id);
      router.refresh();
    } catch {
      // The cover stays put. RLS refuses a delete that isn't the author's,
      // and a transient failure shouldn't look like the item vanished.
      setBusyId(null);
    }
  }

  async function handleRate(item: LibraryItem, choice: RatingChoice | null) {
    setBusyId(item.id);
    setEditingId(null);
    try {
      await updatePostRating(createClient(), item.id, ratingToPost(choice));
      router.refresh();
    } finally {
      setBusyId(null);
    }
  }

  /** The chip that matches a stored rating, so Edit opens on the current value. */
  function choiceFor(item: LibraryItem): RatingChoice | null {
    if (item.rating === null) return null;
    if (item.rating >= 5) return "love";
    if (item.rating >= 3) return "like";
    return "dislike";
  }

  return (
    <section className="flex flex-col gap-3">
      <div role="tablist" className="flex gap-4 border-b border-(--color-separator)">
        {tabs.map((tab) => {
          const selected = shelf === tab.shelf;
          return (
            <button
              key={tab.shelf}
              type="button"
              role="tab"
              aria-selected={selected}
              onClick={() => {
                setShelf(tab.shelf);
                // A kind that exists on one shelf may not on the other, and
                // silently showing an empty grid reads as data loss.
                setKind(null);
              }}
              className={
                selected
                  ? "-mb-px border-b-2 border-(--color-accent) pb-2 font-semibold text-(--color-text-primary)"
                  : "-mb-px border-b-2 border-transparent pb-2 text-(--color-text-secondary)"
              }
            >
              {tab.label}
            </button>
          );
        })}
      </div>

      <MediaKindFilter selected={kind} onSelect={setKind} available={available} />

      {movingId && (
        // The mode has to announce itself. Picking "Reorder" out of a menu
        // and then finding every cover behaves differently is otherwise a
        // surprise with no explanation on screen.
        <div className="flex items-center gap-3 text-sm">
          <span className="text-(--color-text-primary)">Tap where it should go</span>
          <button
            type="button"
            onClick={() => setMovingId(null)}
            className="text-(--color-text-secondary) hover:text-(--color-text-primary)"
          >
            Cancel
          </button>
        </div>
      )}

      {visible.length === 0 ? (
        <p className="pt-1 text-(--color-text-secondary)">
          {items.length === 0 ? emptyMessage : "Nothing of that type here yet."}
        </p>
      ) : (
        <ul className="grid grid-cols-3 gap-2 sm:grid-cols-4 lg:grid-cols-6 xl:grid-cols-8">
          {ordered.map((item, index) => (
            <li
              key={item.id}
              className={["group relative", movingId === item.id ? "opacity-40" : ""].join(" ")}
            >
              {movingId && movingId !== item.id ? (
                // While something is held, every other cover is a place to
                // put it rather than a link to open it.
                <button
                  type="button"
                  onClick={() => placeAt(index)}
                  aria-label={`Move here, before ${item.media.title}`}
                  className="block w-full rounded-sm ring-2 ring-(--color-accent)/40 ring-offset-2 ring-offset-(--color-background) transition hover:ring-(--color-accent)"
                >
                  <MediaCover media={item.media} />
                </button>
              ) : (
                <Link href={`/media/${item.media.id}`}>
                  <MediaCover media={item.media} />
                </Link>
              )}
              {canEdit && (
                <MediaOverflowMenu
                  label={`Options for ${item.media.title}`}
                  busy={busyId === item.id}
                  actions={[
                    { label: "Edit", onSelect: () => setEditingId(item.id) },
                    ...(reorderable && ordered.length > 1
                      ? [{ label: "Reorder", onSelect: () => setMovingId(item.id) }]
                      : []),
                    {
                      label: "Remove",
                      destructive: true,
                      onSelect: () => void handleRemove(item)
                    }
                  ]}
                />
              )}
              {editingId === item.id && (
                <div className="absolute inset-x-0 top-full z-20 mt-1 rounded-md border border-(--color-separator) bg-(--color-background) p-2 shadow-lg">
                  <RatingChips
                    value={choiceFor(item)}
                    onChange={(choice) => void handleRate(item, choice)}
                  />
                </div>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
