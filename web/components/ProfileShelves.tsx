"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMemo, useState } from "react";
import { MediaCover } from "@/components/MediaCover";
import { MediaKindFilter, type KindFilter } from "@/components/MediaKindFilter";
import { removeFromLibrary, type LibraryItem } from "@/lib/library";
import type { MediaKind } from "@/lib/media";
import { createClient } from "@/lib/supabase/client";

type Shelf = "collection" | "watchlist";

interface ProfileShelvesProps {
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

const TABS: { shelf: Shelf; label: string }[] = [
  { shelf: "collection", label: "Collection" },
  { shelf: "watchlist", label: "Watchlist" },
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
  collection,
  watchlist,
  emptyCollection,
  emptyWatchlist,
  canEdit = false,
}: ProfileShelvesProps) {
  const router = useRouter();
  const [shelf, setShelf] = useState<Shelf>("collection");
  const [kind, setKind] = useState<KindFilter>(null);
  const [removingId, setRemovingId] = useState<string | null>(null);

  const items = shelf === "collection" ? collection : watchlist;
  const emptyMessage = shelf === "collection" ? emptyCollection : emptyWatchlist;

  const available = useMemo(
    () => new Set<MediaKind>(items.map((item) => item.media.kind)),
    [items]
  );
  const visible = kind ? items.filter((item) => item.media.kind === kind) : items;

  async function handleRemove(item: LibraryItem) {
    setRemovingId(item.id);
    try {
      await removeFromLibrary(createClient(), item.id);
      router.refresh();
    } catch {
      // The cover stays put. RLS refuses a delete that isn't the author's,
      // and a transient failure shouldn't look like the item vanished.
      setRemovingId(null);
    }
  }

  return (
    <section className="flex flex-col gap-3">
      <div role="tablist" className="flex gap-4 border-b border-(--color-separator)">
        {TABS.map((tab) => {
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

      {visible.length === 0 ? (
        <p className="pt-1 text-(--color-text-secondary)">
          {items.length === 0 ? emptyMessage : "Nothing of that type here yet."}
        </p>
      ) : (
        <ul className="grid grid-cols-3 gap-2">
          {visible.map((item) => (
            <li key={item.id} className="flex flex-col gap-1">
              <Link href={`/media/${item.media.id}`}>
                <MediaCover media={item.media} />
              </Link>
              {canEdit && (
                <button
                  type="button"
                  onClick={() => void handleRemove(item)}
                  disabled={removingId === item.id}
                  aria-label={`Remove ${item.media.title}`}
                  className="text-left text-xs text-(--color-text-secondary) hover:text-red-500 disabled:opacity-50"
                >
                  Remove
                </button>
              )}
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
