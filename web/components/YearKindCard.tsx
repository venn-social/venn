import type { KindStats } from "@/lib/yearInReview";
import { StarIcon } from "@/components/Icon";

const PLURAL: Record<KindStats["kind"], string> = {
  movie: "Movies",
  show: "Shows",
  book: "Books",
  album: "Albums"
};

/** One media kind's totals. Ports YearInReviewKindCard.swift. */
export function YearKindCard({ stats }: { stats: KindStats }) {
  return (
    <div className="flex items-center gap-3 rounded-md bg-(--color-surface) p-4">
      <div className="flex flex-col gap-0.5">
        <p className="font-semibold text-(--color-text-primary)">{PLURAL[stats.kind]}</p>
        {stats.topCreator && (
          <p className="truncate text-sm text-(--color-text-secondary)">
            Most logged: {stats.topCreator}
          </p>
        )}
      </div>

      <div className="ml-auto flex flex-col items-end gap-0.5">
        <p className="text-xl font-semibold tabular-nums text-(--color-text-primary)">
          {stats.consumedCount}
        </p>
        {stats.avgRating !== null && (
          <p className="flex items-center gap-1 text-sm font-semibold text-(--color-text-primary)">
            <StarIcon size={14} className="text-(--color-accent)" /> {stats.avgRating.toFixed(1)}
          </p>
        )}
      </div>
    </div>
  );
}
