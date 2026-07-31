import { describe, expect, it } from "vitest";
import { MAX_RADIUS, MIN_RADIUS, pairGeometry } from "@/lib/vennGeometry";

describe("pairGeometry", () => {
  it("gives the larger side the max radius when one side is empty", () => {
    const geometry = pairGeometry(50, 0, 0);
    expect(geometry.viewerRadius).toBeCloseTo(MAX_RADIUS);
    expect(geometry.otherRadius).toBeCloseTo(MIN_RADIUS);
  });

  it("gives both sides the same radius when counts are equal", () => {
    const geometry = pairGeometry(20, 20, 5);
    expect(geometry.viewerRadius).toBeCloseTo(geometry.otherRadius);
  });

  it("moves centers closer together as the shared fraction grows", () => {
    const lowOverlap = pairGeometry(20, 20, 1);
    const highOverlap = pairGeometry(20, 20, 19);
    expect(highOverlap.halfDistance).toBeLessThan(lowOverlap.halfDistance);
  });

  it("never lets centers drift closer than 65% of the larger radius", () => {
    // shared == union (total overlap): halfDistance should hit its floor.
    const geometry = pairGeometry(20, 20, 20);
    const expectedMinHalfDistance =
      (Math.max(geometry.viewerRadius, geometry.otherRadius) * 0.65) / 2;
    expect(geometry.halfDistance).toBeCloseTo(expectedMinHalfDistance);
  });

  it("handles all-zero counts without dividing by zero", () => {
    const geometry = pairGeometry(0, 0, 0);
    expect(Number.isFinite(geometry.viewerRadius)).toBe(true);
    expect(Number.isFinite(geometry.otherRadius)).toBe(true);
    expect(Number.isFinite(geometry.halfDistance)).toBe(true);
  });
});
