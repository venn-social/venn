import { describe, expect, it } from "vitest";
import {
  MIN_SAMPLE,
  commitmentFor,
  empiricalCommitment,
  referenceCommitment
} from "@/lib/taste/commitment";
import type { MediaKind } from "@/lib/media";

describe("referenceCommitment", () => {
  it.each<[MediaKind, number, number]>([
    ["movie", 95, 0.3],
    ["book", 600, 0.85],
    ["album", 38, 0.4],
    // six seasons × ten 45-minute episodes
    ["show", 2700, 0.95]
  ])("lands the spec's example: %s of length %d ≈ %d", (kind, length, expected) => {
    expect(referenceCommitment(kind, length)).toBeCloseTo(expected, 2);
  });

  it("is monotonic and clamped to [0, 1]", () => {
    for (const kind of ["movie", "show", "book", "album"] as MediaKind[]) {
      let previous = -1;
      for (let length = 1; length <= 7000; length += 7) {
        const value = referenceCommitment(kind, length);
        expect(value).toBeGreaterThanOrEqual(previous);
        expect(value).toBeGreaterThanOrEqual(0);
        expect(value).toBeLessThanOrEqual(1);
        previous = value;
      }
    }
  });
});

describe("empiricalCommitment", () => {
  it("uses mid-rank, so ties count half", () => {
    expect(empiricalCommitment([10, 20, 20, 30], 20)).toBe(0.5);
    expect(empiricalCommitment([10, 20, 30], 5)).toBe(0);
    expect(empiricalCommitment([10, 20, 30], 40)).toBe(1);
  });
});

describe("commitmentFor", () => {
  it("uses the reference curve below the sample threshold", () => {
    const small = Array.from({ length: MIN_SAMPLE - 1 }, () => 300);
    expect(commitmentFor("movie", 95, small)).toBe(0.3);
  });

  it("switches to the real percentile once the kind has enough items", () => {
    const sample = Array.from({ length: MIN_SAMPLE }, (_, i) => 60 + i);
    expect(commitmentFor("movie", 160, sample)).toBe(0.502);
  });

  it("is null without a length", () => {
    expect(commitmentFor("book", null, [])).toBeNull();
    expect(commitmentFor("book", 0, [])).toBeNull();
  });
});
