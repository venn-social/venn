"use client";

import { useState } from "react";
import { MediaCover } from "@/components/MediaCover";
import type { LibraryItem } from "@/lib/library";

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
}

const TABS: { shelf: Shelf; label: string }[] = [
  { shelf: "collection", label: "Collection" },
  { shelf: "watchlist", label: "Watchlist" },
];

/**
 * Collection / Watchlist tabs above a three-column cover grid, porting
 * ShelfTabs.swift + ProfileShelfGallery.swift. Collection is everything
 * logged or rated; Watchlist is everything saved.
 */
export function ProfileShelves({
  collection,
  watchlist,
  emptyCollection,
  emptyWatchlist,
}: ProfileShelvesProps) {
  const [shelf, setShelf] = useState<Shelf>("collection");

  const items = shelf === "collection" ? collection : watchlist;
  const emptyMessage = shelf === "collection" ? emptyCollection : emptyWatchlist;

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
              onClick={() => setShelf(tab.shelf)}
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

      {items.length === 0 ? (
        <p className="pt-1 text-(--color-text-secondary)">{emptyMessage}</p>
      ) : (
        <ul className="grid grid-cols-3 gap-2">
          {items.map((item) => (
            <li key={item.id}>
              <MediaCover media={item.media} />
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
