"use client";

import type { MediaKind } from "@/lib/media";

/** null means "everything" — the default, and always first. */
export type KindFilter = MediaKind | null;

const FILTERS: { kind: KindFilter; label: string }[] = [
  { kind: null, label: "All" },
  { kind: "movie", label: "Movies" },
  { kind: "show", label: "Shows" },
  { kind: "book", label: "Books" },
  { kind: "album", label: "Albums" },
];

interface MediaKindFilterProps {
  selected: KindFilter;
  onSelect: (kind: KindFilter) => void;
  /**
   * Kinds actually present in the current shelf. A filter that would show
   * an empty grid is not offered — with four kinds and often one, a row of
   * dead chips is worse than no row.
   */
  available: ReadonlySet<MediaKind>;
}

export function MediaKindFilter({ selected, onSelect, available }: MediaKindFilterProps) {
  const shown = FILTERS.filter((f) => f.kind === null || available.has(f.kind));

  // One kind (or none) means the filter cannot narrow anything.
  if (shown.length <= 2) return null;

  return (
    <div role="tablist" aria-label="Filter by type" className="flex flex-wrap gap-2">
      {shown.map((filter) => {
        const active = selected === filter.kind;
        return (
          <button
            key={filter.label}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onSelect(filter.kind)}
            className={
              active
                ? "rounded-pill bg-(--color-accent) px-3 py-1 text-sm font-semibold text-(--color-on-accent)"
                : "rounded-pill bg-(--color-surface) px-3 py-1 text-sm text-(--color-text-secondary) hover:text-(--color-text-primary)"
            }
          >
            {filter.label}
          </button>
        );
      })}
    </div>
  );
}
