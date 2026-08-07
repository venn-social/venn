import { describe, expect, it } from "vitest";
import { movedOrder, type ListItem } from "@/lib/lists";

function item(id: string, position: number): ListItem {
  return {
    media: {
      id,
      kind: "movie",
      title: `Title ${id}`,
      year: null,
      primaryCreator: null,
      coverUrl: null,
      externalId: null,
      externalSource: null
    },
    position,
    note: null
  };
}

const items = [item("a", 0), item("b", 1), item("c", 2)];

describe("movedOrder", () => {
  it("moves an item up one place", () => {
    expect(movedOrder(items, "b", "up")).toEqual(["b", "a", "c"]);
  });

  it("moves an item down one place", () => {
    expect(movedOrder(items, "b", "down")).toEqual(["a", "c", "b"]);
  });

  it("leaves the first item alone when asked to move it up", () => {
    // The control is hidden at the ends, but the rule belongs here too —
    // a wrap-around would silently reorder the whole list.
    expect(movedOrder(items, "a", "up")).toEqual(["a", "b", "c"]);
  });

  it("leaves the last item alone when asked to move it down", () => {
    expect(movedOrder(items, "c", "down")).toEqual(["a", "b", "c"]);
  });

  it("ignores an id that is not in the list", () => {
    expect(movedOrder(items, "zzz", "up")).toEqual(["a", "b", "c"]);
  });

  it("returns the full order, not just the pair that moved", () => {
    // The RPC rewrites every position from this array, so a partial answer
    // would blank the rest of the list.
    expect(movedOrder(items, "c", "up")).toHaveLength(3);
  });

  it("handles a single-item list without moving anything", () => {
    expect(movedOrder([item("only", 0)], "only", "down")).toEqual(["only"]);
  });
});
