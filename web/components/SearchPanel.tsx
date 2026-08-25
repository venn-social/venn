"use client";

import { CategoryChips, type ExploreCategory } from "@/components/CategoryChips";

interface SearchPanelProps {
  category: ExploreCategory;
  onCategoryChange: (next: ExploreCategory) => void;
  query: string;
  onQueryChange: (next: string) => void;
  placeholder: string;
  /** Categories to leave out — the composer has no use for "people". */
  exclude?: ExploreCategory[];
}

/**
 * Category tabs and a search field, as one panel.
 *
 * Extracted so Explorer and the composer are the same control rather than
 * two that resemble each other — they ask the same question, and the only
 * difference between them is that you cannot log a person.
 *
 * The panel bleeds to the column's edges and is square at the top and
 * rounded at the foot, so it reads as hanging from the chrome above rather
 * than floating in the page. The field carries no border of its own: the
 * panel's edge already says where it starts.
 */
export function SearchPanel({
  category,
  onCategoryChange,
  query,
  onQueryChange,
  placeholder,
  exclude
}: SearchPanelProps) {
  return (
    <div className="-mx-4 overflow-hidden rounded-b-2xl border border-t-0 border-(--color-separator) bg-(--color-background)">
      <div className="px-4 pt-3">
        <CategoryChips value={category} onChange={onCategoryChange} exclude={exclude} />
      </div>

      <input
        type="text"
        value={query}
        onChange={(event) => onQueryChange(event.target.value)}
        placeholder={placeholder}
        className="w-full bg-transparent px-4 py-3 text-sm text-(--color-text-primary) outline-none placeholder:text-(--color-text-secondary)"
      />
    </div>
  );
}
