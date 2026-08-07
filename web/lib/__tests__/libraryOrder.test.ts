import { describe, expect, it } from "vitest";
import { movedLibraryOrder, type LibraryItem } from "@/lib/library";

function item(id: string): LibraryItem {
  return {
    id,
    action: "logged",
    rating: null,
    createdAt: new Date("2026-08-01T10:00:00Z"),
    media: {
      id: `m-${id}`,
      kind: "movie",
      title: `Title ${id}`,
      year: null,
      primaryCreator: null,
      coverUrl: null,
      externalSource: null,
      externalId: null
    }
  };
}

const items = [item("a"), item("b"), item("c"), item("d")];

describe("movedLibraryOrder", () => {
  it("moves an item forward, closing the gap behind it", () => {
    expect(movedLibraryOrder(items, "a", 2)).toEqual(["b", "c", "a", "d"]);
  });

  it("moves an item backward", () => {
    expect(movedLibraryOrder(items, "d", 1)).toEqual(["a", "d", "b", "c"]);
  });

  it("moves an item to the very front", () => {
    expect(movedLibraryOrder(items, "c", 0)).toEqual(["c", "a", "b", "d"]);
  });

  it("moves an item to the very end", () => {
    expect(movedLibraryOrder(items, "a", 3)).toEqual(["b", "c", "d", "a"]);
  });

  it("is a no-op when dropped where it started", () => {
    expect(movedLibraryOrder(items, "b", 1)).toEqual(["a", "b", "c", "d"]);
  });

  it("ignores a target past either end", () => {
    // The grid clamps, but a wrap-around here would scramble the shelf.
    expect(movedLibraryOrder(items, "a", 9)).toEqual(["a", "b", "c", "d"]);
    expect(movedLibraryOrder(items, "a", -1)).toEqual(["a", "b", "c", "d"]);
  });

  it("ignores an id that is not on the shelf", () => {
    expect(movedLibraryOrder(items, "zzz", 0)).toEqual(["a", "b", "c", "d"]);
  });

  it("always returns every id, never a slice", () => {
    // The RPC rewrites positions from this array, so a partial answer would
    // leave the rest of the shelf unplaced.
    expect(movedLibraryOrder(items, "c", 0)).toHaveLength(items.length);
  });

  it("handles a single-item shelf", () => {
    expect(movedLibraryOrder([item("only")], "only", 0)).toEqual(["only"]);
  });
});
