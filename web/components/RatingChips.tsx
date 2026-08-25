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
            // The word said what the icon already says. It moves to the
            // accessible name, which is the only place it was doing work.
            aria-label={label}
            title={label}
            className={
              selected
                ? "flex h-11 w-11 items-center justify-center rounded-pill bg-(--color-accent) text-(--color-on-accent)"
                : "flex h-11 w-11 items-center justify-center rounded-pill border border-(--color-separator) text-(--color-text-secondary) hover:text-(--color-text-primary)"
            }
          >
            <Icon filled={selected && choice === "love"} />
          </button>
        );
      })}
    </div>
  );
}
