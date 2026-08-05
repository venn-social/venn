import { describe, expect, it } from "vitest";
import { toList, toListItems, toLists } from "@/lib/lists";

const listRow = {
  id: "l1",
  owner_id: "u1",
  title: "Best of 2026",
  description: "So far.",
  is_public: true,
  created_at: "2026-08-01T00:00:00Z",
  updated_at: "2026-08-05T00:00:00Z"
};

describe("toList", () => {
  it("maps a complete row", () => {
    const list = toList(listRow);

    expect(list.title).toBe("Best of 2026");
    expect(list.isPublic).toBe(true);
    expect(list.createdAt).toBeInstanceOf(Date);
    expect(list.updatedAt).toBeInstanceOf(Date);
  });

  it("keeps a null description rather than coercing it to empty text", () => {
    expect(toList({ ...listRow, description: null }).description).toBeNull();
  });

  it("carries through a private list", () => {
    expect(toList({ ...listRow, is_public: false }).isPublic).toBe(false);
  });
});

describe("toLists", () => {
  it("returns an empty array for null", () => {
    expect(toLists(null)).toEqual([]);
  });
});

describe("toListItems", () => {
  it("maps items with their position and note", () => {
    const items = toListItems([
      {
        position: 2,
        note: "The ending.",
        media: { id: "m1", kind: "movie", title: "Past Lives", year: 2023 }
      }
    ]);

    expect(items).toHaveLength(1);
    expect(items[0].media.title).toBe("Past Lives");
    expect(items[0].position).toBe(2);
    expect(items[0].note).toBe("The ending.");
  });

  it("drops items whose media kind is unknown", () => {
    const items = toListItems([
      { position: 0, media: { id: "m1", kind: "hologram", title: "Weird" } },
      { position: 1, media: { id: "m2", kind: "book", title: "Fine" } }
    ]);
    expect(items.map((item) => item.media.title)).toEqual(["Fine"]);
  });

  it("defaults a missing position to zero rather than dropping the item", () => {
    const items = toListItems([{ media: { id: "m1", kind: "book", title: "Piranesi" } }]);
    expect(items[0].position).toBe(0);
  });

  it("returns an empty array for null", () => {
    expect(toListItems(null)).toEqual([]);
  });
});
