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
 * Category tabs and a search field.
 *
 * Extracted so Explorer and the composer are the same control rather than
 * two that resemble each other — they ask the same question, and the only
 * difference between them is that you cannot log a person.
 *
 * One hairline, and it belongs to the tabs. An earlier version boxed the
 * pair in a panel, which meant a border down each side, another along the
 * bottom, and the tab rule inside it — four lines to say what one already
 * said. The field takes no border of its own: its placeholder says what it
 * is, and directly under the tabs there is nothing else it could be.
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
    <div className="flex flex-col">
      <CategoryChips value={category} onChange={onCategoryChange} exclude={exclude} />

      <input
        type="text"
        value={query}
        onChange={(event) => onQueryChange(event.target.value)}
        placeholder={placeholder}
        className="w-full bg-transparent py-3 text-sm text-(--color-text-primary) outline-none placeholder:text-(--color-text-secondary)"
      />
    </div>
  );
}
