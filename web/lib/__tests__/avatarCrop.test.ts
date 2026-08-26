import { describe, expect, it } from "vitest";
import {
  clampOffset,
  coverScale,
  drawnSize,
  offsetAfterZoom,
  outputRect,
  type CropView
} from "@/lib/avatarCrop";

/**
 * The half of the avatar cropper that can be wrong without looking wrong:
 * an off-by-one in the clamp is a sliver of background at one edge, easy
 * to miss by eye and trivial to assert.
 */

/** A landscape photo, in a 260px window. */
const wide: CropView = { width: 1000, height: 500, viewport: 260, zoom: 1 };
/** A portrait one. */
const tall: CropView = { width: 500, height: 1000, viewport: 260, zoom: 1 };

describe("coverScale", () => {
  it("scales the short side to the window, so nothing is ever letterboxed", () => {
    expect(coverScale(wide)).toBe(260 / 500);
    expect(coverScale(tall)).toBe(260 / 500);
  });

  it("survives a zero-sized image instead of dividing by it", () => {
    expect(coverScale({ width: 0, height: 0, viewport: 260 })).toBe(1);
  });
});

describe("drawnSize", () => {
  it("covers the window exactly at zoom 1", () => {
    const drawn = drawnSize(wide);
    expect(Math.min(drawn.width, drawn.height)).toBeCloseTo(260);
    expect(drawn.width).toBeGreaterThan(260);
  });

  it("grows with zoom", () => {
    expect(drawnSize({ ...wide, zoom: 2 }).width).toBeCloseTo(drawnSize(wide).width * 2);
  });
});

describe("clampOffset", () => {
  it("never lets the picture pull away from an edge", () => {
    // The one thing that would leave a gap in the circle.
    const drawn = drawnSize(wide);
    for (const attempt of [
      { x: 500, y: 500 },
      { x: -5000, y: -5000 },
      { x: 0, y: 40 }
    ]) {
      const { x, y } = clampOffset(wide, attempt);
      expect(x).toBeLessThanOrEqual(0);
      expect(y).toBeLessThanOrEqual(0);
      expect(x).toBeGreaterThanOrEqual(260 - drawn.width);
      expect(y).toBeGreaterThanOrEqual(260 - drawn.height);
    }
  });

  it("pins the axis that exactly fits, leaving the other free", () => {
    // A landscape photo at zoom 1 fits vertically to the pixel; only
    // sideways movement is meaningful.
    expect(clampOffset(wide, { x: -100, y: -100 })).toEqual({ x: -100, y: 0 });
    expect(clampOffset(tall, { x: -100, y: -100 })).toEqual({ x: 0, y: -100 });
  });
});

describe("outputRect", () => {
  it("reproduces what the window showed, at the output's scale", () => {
    // 512 output over a 260 window is the same picture, just bigger.
    const rect = outputRect(wide, { x: -60, y: 0 }, 512);
    const factor = 512 / 260;
    expect(rect.x).toBeCloseTo(-60 * factor);
    expect(rect.width).toBeCloseTo(drawnSize(wide).width * factor);
  });

  it("clamps before it scales, so a bad offset cannot leak into the file", () => {
    const rect = outputRect(wide, { x: 999, y: 999 }, 512);
    expect(rect.x).toBe(0);
    expect(rect.y).toBe(0);
  });

  it("always covers the output canvas", () => {
    for (const zoom of [1, 1.7, 4]) {
      for (const view of [wide, tall]) {
        const rect = outputRect({ ...view, zoom }, { x: -10, y: -10 }, 512);
        expect(rect.width).toBeGreaterThanOrEqual(512 - 0.001);
        expect(rect.height).toBeGreaterThanOrEqual(512 - 0.001);
      }
    }
  });
});

describe("offsetAfterZoom", () => {
  it("keeps the middle of the window on the same part of the picture", () => {
    // Otherwise zooming walks the picture into a corner and you drag it
    // back every time.
    const before = { x: -120, y: 0 };
    const centreBefore = (260 / 2 - before.x) / drawnSize(wide).width;

    const after = offsetAfterZoom(wide, before, 2);
    const centreAfter = (260 / 2 - after.x) / drawnSize({ ...wide, zoom: 2 }).width;

    expect(centreAfter).toBeCloseTo(centreBefore, 5);
  });

  it("still refuses to expose an edge while doing it", () => {
    const after = offsetAfterZoom({ ...wide, zoom: 3 }, { x: -600, y: -100 }, 1);
    expect(after).toEqual(clampOffset({ ...wide, zoom: 1 }, after));
  });
});
