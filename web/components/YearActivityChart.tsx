import { barRatio, monthLabel, type MonthlyStat } from "@/lib/yearInReview";

const CHART_HEIGHT = 120;
/** Empty months still show a sliver, so the axis reads as a chart. */
const MIN_BAR_HEIGHT = 4;

/**
 * Trailing-twelve-month activity. Plain CSS bars, not a charting library —
 * the same call YearInReviewMonthlyChart.swift makes with Capsule over
 * Apple's Charts framework.
 */
export function YearActivityChart({ monthly }: { monthly: MonthlyStat[] }) {
  const max = Math.max(0, ...monthly.map((point) => point.count));
  const summary = monthly.map((point) => `${monthLabel(point.month)}: ${point.count}`).join(", ");

  return (
    <section className="flex flex-col gap-2">
      <h2 className="text-xs font-semibold tracking-wide text-(--color-text-secondary) uppercase">
        Activity
      </h2>

      <div
        // One spoken summary, bars hidden — twelve separate labels are
        // noise to a screen reader.
        aria-label={`Monthly activity, trailing twelve months. ${summary}.`}
        className="flex items-end gap-1"
        style={{ height: CHART_HEIGHT }}
      >
        {monthly.map((point) => {
          const ratio = barRatio(point.count, max);
          return (
            <div key={point.month} className="flex flex-1 flex-col items-center gap-1">
              <div
                aria-hidden="true"
                className={
                  ratio > 0
                    ? "w-full rounded-pill bg-(--color-accent)"
                    : "w-full rounded-pill bg-(--color-surface-strong)"
                }
                style={{ height: Math.max(MIN_BAR_HEIGHT, ratio * (CHART_HEIGHT - 20)) }}
              />
              <span className="text-[10px] text-(--color-text-secondary)">
                {monthLabel(point.month)}
              </span>
            </div>
          );
        })}
      </div>
    </section>
  );
}
