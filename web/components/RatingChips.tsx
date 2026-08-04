"use client";

import type { RatingChoice } from "@/lib/compose";

interface RatingChipsProps {
  value: RatingChoice | null;
  onChange: (next: RatingChoice | null) => void;
}

/** Same three choices and emoji as ComposerSheetView's ratingChip row. */
const CHOICES: { choice: RatingChoice; emoji: string; label: string }[] = [
  { choice: "love", emoji: "❤️", label: "Love" },
  { choice: "like", emoji: "👍", label: "Like" },
  { choice: "dislike", emoji: "👎", label: "Dislike" }
];

export function RatingChips({ value, onChange }: RatingChipsProps) {
  return (
    <div className="flex gap-2">
      {CHOICES.map(({ choice, emoji, label }) => {
        const selected = value === choice;
        return (
          <button
            key={choice}
            type="button"
            aria-pressed={selected}
            // Clicking the current choice clears it, so skipping needs no
            // separate control.
            onClick={() => onChange(selected ? null : choice)}
            className={
              selected
                ? "rounded-pill border border-(--color-accent) bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent)"
                : "rounded-pill border border-(--color-separator) px-4 py-2 font-semibold text-(--color-text-primary)"
            }
          >
            <span aria-hidden="true">{emoji}</span> {label}
          </button>
        );
      })}
    </div>
  );
}
