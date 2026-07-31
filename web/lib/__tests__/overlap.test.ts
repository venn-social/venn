import { describe, expect, it } from "vitest";
import { summarize, tasteMatchPercent, type KindOverlap } from "@/lib/overlap";

describe("summarize", () => {
  it("sums counts across kinds", () => {
    const kinds: KindOverlap[] = [
      { kind: "movie", viewerCount: 12, otherCount: 8, sharedCount: 3 },
      { kind: "book", viewerCount: 5, otherCount: 9, sharedCount: 2 },
      { kind: "album", viewerCount: 0, otherCount: 4, sharedCount: 0 }
    ];

    const summary = summarize(kinds);

    expect(summary.viewerTotal).toBe(17);
    expect(summary.otherTotal).toBe(21);
    expect(summary.sharedTotal).toBe(5);
  });

  it("sums to all zeros for an empty kinds list", () => {
    const summary = summarize([]);
    expect(summary).toEqual({ kinds: [], viewerTotal: 0, otherTotal: 0, sharedTotal: 0 });
  });
});

describe("tasteMatchPercent", () => {
  it("computes Jaccard similarity across kinds", () => {
    // viewer 17, other 21, shared 5 -> union 33 -> 5/33 ~= 15%.
    expect(tasteMatchPercent(5, 17, 21)).toBe(15);
  });

  it("returns null when there is nothing to compare", () => {
    expect(tasteMatchPercent(0, 0, 0)).toBeNull();
  });

  it("returns 100 for identical collections", () => {
    expect(tasteMatchPercent(10, 10, 10)).toBe(100);
  });

  it("returns 0 when nothing is shared", () => {
    expect(tasteMatchPercent(0, 20, 15)).toBe(0);
  });

  it("rounds to the nearest whole number", () => {
    // 1 of 3 union -> 33.33% -> 33.
    expect(tasteMatchPercent(1, 2, 2)).toBe(33);
    // 2 of 3 union -> 66.66% -> 67.
    expect(tasteMatchPercent(2, 3, 2)).toBe(67);
  });
});
