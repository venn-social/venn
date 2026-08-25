"use client";

import type { MediaKind } from "@/lib/media";

/** Ports ExplorerCategory.swift — same six cases, same titles. */
export type ExploreCategory = "all" | "people" | "movies" | "tv" | "music" | "books";

export const CATEGORIES: { category: ExploreCategory; label: string }[] = [
  { category: "all", label: "All" },
  { category: "people", label: "People" },
  { category: "movies", label: "Movies" },
  { category: "tv", label: "TV" },
  { category: "music", label: "Music" },
  { category: "books", label: "Books" }
];

/** Media kinds this category searches. Empty for People — that goes to profiles. */
export function searchKindsFor(category: ExploreCategory): MediaKind[] {
  switch (category) {
    case "all":
      return ["movie", "show", "album", "book"];
    case "movies":
      return ["movie"];
    case "tv":
      return ["show"];
    case "music":
      return ["album"];
    case "books":
      return ["book"];
    default:
      return [];
  }
}

/** The single kind the browse panel loads. Null for All and People. */
export function browseKindFor(category: ExploreCategory): MediaKind | null {
  const kinds = searchKindsFor(category);
  return category === "all" || kinds.length !== 1 ? null : kinds[0];
}

interface CategoryChipsProps {
  value: ExploreCategory;
  onChange: (next: ExploreCategory) => void;
  /**
   * Categories to leave out. The composer drops "people": you cannot log a
   * person, and offering the tab would lead somewhere with nothing to do.
   */
  exclude?: ExploreCategory[];
}

export function CategoryChips({ value, onChange, exclude = [] }: CategoryChipsProps) {
  const shown = CATEGORIES.filter(({ category }) => !exclude.includes(category));

  return (
    // Underline tabs, matching the Collection / Watchlist control on the
    // profile. These pick which slice of the catalog you are looking at,
    // which is the same job those tabs do — a row of filled pills read as
    // six competing actions instead of one choice among six.
    <div role="tablist" aria-label="Search category" className="flex gap-4 border-b border-(--color-separator)">
      {shown.map(({ category, label }) => {
        const selected = value === category;
        return (
          <button
            key={category}
            type="button"
            role="tab"
            aria-selected={selected}
            onClick={() => onChange(category)}
            className={
              selected
                ? "-mb-px border-b-2 border-(--color-accent) pb-2 font-semibold text-(--color-text-primary)"
                : "-mb-px border-b-2 border-transparent pb-2 text-(--color-text-secondary) hover:text-(--color-text-primary)"
            }
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
