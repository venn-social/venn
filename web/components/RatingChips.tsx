"use client";

import { HeartIcon, ThumbsDownIcon, ThumbsUpIcon } from "@/components/Icon";
import type { RatingChoice } from "@/lib/compose";

interface RatingChipsProps {
  value: RatingChoice | null;
  onChange: (next: RatingChoice | null) => void;
}

/** Same three choices as ComposerSheetView's ratingChip row. */
const CHOICES: {
  choice: RatingChoice;
  Icon: typeof HeartIcon;
  label: string;
}[] = [
  { choice: "love", Icon: HeartIcon, label: "Love" },
  { choice: "like", Icon: ThumbsUpIcon, label: "Like" },
  { choice: "dislike", Icon: ThumbsDownIcon, label: "Dislike" }
];

export function RatingChips({ value, onChange }: RatingChipsProps) {
  return (
    <div className="flex gap-2">
      {CHOICES.map(({ choice, Icon, label }) => {
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
                ? "flex items-center gap-1.5 rounded-pill border border-(--color-accent) bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent)"
                : "flex items-center gap-1.5 rounded-pill border border-(--color-separator) px-4 py-2 font-semibold text-(--color-text-primary)"
            }
          >
            <Icon filled={selected && choice === "love"} />
            {label}
          </button>
        );
      })}
    </div>
  );
}
