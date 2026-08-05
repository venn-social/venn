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
}

export function CategoryChips({ value, onChange }: CategoryChipsProps) {
  return (
    <div className="flex flex-wrap gap-2">
      {CATEGORIES.map(({ category, label }) => {
        const selected = value === category;
        return (
          <button
            key={category}
            type="button"
            aria-pressed={selected}
            onClick={() => onChange(category)}
            className={
              selected
                ? "rounded-pill bg-(--color-accent) px-3 py-1.5 text-sm font-semibold text-(--color-on-accent)"
                : "rounded-pill border border-(--color-separator) px-3 py-1.5 text-sm text-(--color-text-primary)"
            }
          >
            {label}
          </button>
        );
      })}
    </div>
  );
}
