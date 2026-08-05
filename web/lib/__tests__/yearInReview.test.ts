import { describe, expect, it } from "vitest";
import {
  barRatio,
  monthLabel,
  toKindStats,
  toMonthlyStats,
  totalConsumed
} from "@/lib/yearInReview";

describe("toKindStats", () => {
  it("maps a complete row", () => {
    const [stats] = toKindStats([
      {
        kind: "movie",
        consumed_count: 12,
        saved_count: 3,
        rated_count: 8,
        avg_rating: 4.25,
        top_creator: "Denis Villeneuve",
        top_creator_count: 3
      }
    ]);

    expect(stats.kind).toBe("movie");
    expect(stats.consumedCount).toBe(12);
    expect(stats.savedCount).toBe(3);
    expect(stats.ratedCount).toBe(8);
    expect(stats.avgRating).toBe(4.25);
    expect(stats.topCreator).toBe("Denis Villeneuve");
  });

  it("parses avg_rating when PostgREST sends numeric as a string", () => {
    const [stats] = toKindStats([{ kind: "movie", consumed_count: 1, avg_rating: "4.50" }]);
    expect(stats.avgRating).toBe(4.5);
  });

  it("handles a kind with nothing rated and no top creator", () => {
    // Both are null constantly — a kind you've logged but never rated has
    // no average, and music often has no single dominant creator.
    const [stats] = toKindStats([
      {
        kind: "book",
        consumed_count: 2,
        saved_count: 0,
        rated_count: 0,
        avg_rating: null,
        top_creator: null,
        top_creator_count: null
      }
    ]);

    expect(stats.avgRating).toBeNull();
    expect(stats.topCreator).toBeNull();
  });

  it("drops rows with an unknown kind", () => {
    const stats = toKindStats([
      { kind: "hologram", consumed_count: 1 },
      { kind: "album", consumed_count: 2 }
    ]);
    expect(stats.map((row) => row.kind)).toEqual(["album"]);
  });

  it("returns an empty array for null or a non-array", () => {
    expect(toKindStats(null)).toEqual([]);
    expect(toKindStats({})).toEqual([]);
  });
});

describe("toMonthlyStats", () => {
  it("keeps the month string and count", () => {
    const [point] = toMonthlyStats([{ month: "2026-08-01", count: 5 }]);
    expect(point.month).toBe("2026-08-01");
    expect(point.count).toBe(5);
  });

  it("treats a missing count as zero rather than dropping the month", () => {
    // A gap in the axis would misrepresent the year; a zero bar is honest.
    const [point] = toMonthlyStats([{ month: "2026-07-01" }]);
    expect(point.count).toBe(0);
  });

  it("returns an empty array for null", () => {
    expect(toMonthlyStats(null)).toEqual([]);
  });
});

describe("totalConsumed", () => {
  it("sums consumed counts across kinds", () => {
    expect(
      totalConsumed([
        { kind: "movie", consumedCount: 12 },
        { kind: "book", consumedCount: 5 }
      ] as never)
    ).toBe(17);
  });

  it("is zero for no kinds", () => {
    expect(totalConsumed([])).toBe(0);
  });
});

describe("barRatio", () => {
  it("scales a count against the busiest month", () => {
    expect(barRatio(5, 10)).toBe(0.5);
    expect(barRatio(10, 10)).toBe(1);
  });

  it("returns zero when nothing was logged all year", () => {
    // Guards the divide-by-zero that an all-empty year would otherwise hit.
    expect(barRatio(0, 0)).toBe(0);
  });

  it("returns zero for an empty month", () => {
    expect(barRatio(0, 8)).toBe(0);
  });
});

describe("monthLabel", () => {
  it("renders a short month name", () => {
    expect(monthLabel("2026-08-01")).toBe("Aug");
  });

  it("passes through an unparseable value rather than throwing", () => {
    expect(monthLabel("not-a-date")).toBe("not-a-date");
  });
});
