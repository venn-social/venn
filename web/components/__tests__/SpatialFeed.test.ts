import { describe, expect, it } from "vitest";
import { visibleCells } from "@/components/SpatialFeed";

/**
 * The plane's one piece of real logic: which cells are on screen, and what
 * each holds. Everything else is scroll position and CSS.
 */

const view = { left: 0, top: 0, width: 400, height: 600 };

describe("visibleCells", () => {
  it("covers the viewport", () => {
    const cells = visibleCells(view, 10);
    const cols = cells.map((c) => c.col);
    const rows = cells.map((c) => c.row);

    // 400px of viewport at 190px cells needs cols 0..2 before overscan.
    expect(Math.min(...cols)).toBeLessThanOrEqual(0);
    expect(Math.max(...cols)).toBeGreaterThanOrEqual(2);
    expect(Math.min(...rows)).toBeLessThanOrEqual(0);
    expect(Math.max(...rows)).toBeGreaterThanOrEqual(2);
  });

  it("keeps a margin beyond the viewport, so panning reveals no gaps", () => {
    const cells = visibleCells(view, 10);
    expect(cells.some((c) => c.col < 0)).toBe(true);
    expect(cells.some((c) => c.row < 0)).toBe(true);
  });

  it("gives a cell the same post every time it is asked", () => {
    // The whole illusion depends on this: pan away and back, and the plane
    // must be where you left it rather than reshuffled.
    const first = visibleCells(view, 7);
    const again = visibleCells(view, 7);
    expect(again).toEqual(first);

    const shifted = visibleCells({ ...view, left: 190 * 4 }, 7);
    const shared = shifted.filter((c) => first.some((f) => f.col === c.col && f.row === c.row));
    for (const cell of shared) {
      const original = first.find((f) => f.col === cell.col && f.row === cell.row);
      expect(cell.index).toBe(original?.index);
    }
  });

  it("works in every direction, not just down and right", () => {
    // Negative coordinates are the whole point — the plane extends up and
    // left of where you started.
    const cells = visibleCells({ left: -2000, top: -3000, width: 400, height: 600 }, 5);
    expect(cells.length).toBeGreaterThan(0);
    expect(cells.every((c) => Number.isInteger(c.index))).toBe(true);
  });

  it("never indexes outside the pool, however far you roam", () => {
    for (const left of [-1e6, -190, 0, 190, 1e6]) {
      for (const pool of [1, 3, 20]) {
        const cells = visibleCells({ ...view, left, top: left }, pool);
        for (const cell of cells) {
          expect(cell.index).toBeGreaterThanOrEqual(0);
          expect(cell.index).toBeLessThan(pool);
        }
      }
    }
  });

  it("never shows the same artwork twice on one screen, given enough posts", () => {
    // The complaint this replaced a scattering formula to fix: the same
    // covers kept landing near each other. With a pool big enough to fill
    // a screen, a screenful must now be entirely distinct.
    const screen = { left: 0, top: 0, width: 1100, height: 760 };
    const onScreen = visibleCells(screen, 60).filter(
      (c) => c.col >= 0 && c.col <= 5 && c.row >= 0 && c.row <= 2
    );

    const indexes = onScreen.map((c) => c.index);
    expect(new Set(indexes).size).toBe(indexes.length);
  });

  it("holds that promise wherever you have wandered to", () => {
    // Distinctness must not be an accident of starting at the origin.
    for (const [left, top] of [
      [12_345, 67_890],
      [-4_321, 9_876],
      [1_000_000, -1_000_000]
    ]) {
      const cells = visibleCells({ left, top, width: 1100, height: 760 }, 60);
      const firstCol = Math.floor(left / 190);
      const firstRow = Math.floor(top / 290);
      const onScreen = cells.filter(
        (c) =>
          c.col >= firstCol && c.col <= firstCol + 5 && c.row >= firstRow && c.row <= firstRow + 2
      );
      const indexes = onScreen.map((c) => c.index);
      expect(new Set(indexes).size).toBe(indexes.length);
    }
  });

  it("still spaces repeats as far as it can when there are too few posts", () => {
    // Twelve posts cannot fill a thirty-cell screen, so repeats are
    // arithmetic rather than a bug. Neighbours must still differ.
    const cells = visibleCells({ left: 0, top: 0, width: 1100, height: 760 }, 12);
    const at = (col: number, row: number) =>
      cells.find((c) => c.col === col && c.row === row)?.index;

    for (let col = 0; col <= 4; col += 1) {
      expect(at(col, 0)).not.toBe(at(col + 1, 0));
      expect(at(col, 0)).not.toBe(at(col, 1));
    }
  });

  it("renders nothing rather than dividing by zero on an empty feed", () => {
    expect(visibleCells(view, 0)).toEqual([]);
  });

  it("renders nothing before the viewport has been measured", () => {
    expect(visibleCells({ left: 0, top: 0, width: 0, height: 0 }, 10)).toEqual([]);
  });
});
