import { describe, expect, it } from "vitest";
import { COLLECTION_ACTIONS, toLibraryItem, WATCHLIST_ACTIONS, type LibraryItemRow } from "@/lib/library";

function row(overrides: Partial<LibraryItemRow> = {}): LibraryItemRow {
  return {
    id: "44444444-4444-4444-4444-444444444444",
    action: "logged",
    rating: null,
    created_at: "2026-08-01T10:00:00Z",
    media: {
      id: "33333333-3333-3333-3333-333333333333",
      kind: "book",
      title: "Piranesi",
      year: 2020,
      primary_creator: "Susanna Clarke",
      cover_url: "https://example.test/piranesi.jpg",
    },
    ...overrides,
  };
}

describe("action groupings", () => {
  it("treats logged and rated as the collection, saved as the watchlist", () => {
    // Mirrors ProfileService.collection(for:kind:) / watchlist(for:kind:).
    expect([...COLLECTION_ACTIONS].sort()).toEqual(["logged", "rated"]);
    expect([...WATCHLIST_ACTIONS]).toEqual(["saved"]);
  });
});

describe("toLibraryItem", () => {
  it("maps a complete row", () => {
    const item = toLibraryItem(row({ rating: 5 }));

    expect(item).not.toBeNull();
    expect(item?.media.title).toBe("Piranesi");
    expect(item?.media.kind).toBe("book");
    expect(item?.rating).toBe(5);
    expect(item?.createdAt).toBeInstanceOf(Date);
  });

  it("drops a row whose media kind is unknown", () => {
    const bad = row();
    bad.media.kind = "sculpture" as LibraryItemRow["media"]["kind"];
    expect(toLibraryItem(bad)).toBeNull();
  });

  it("drops a row with no joined media at all", () => {
    // An inner join should prevent this, but a null here would otherwise
    // throw while rendering the shelf.
    expect(toLibraryItem(row({ media: null as unknown as LibraryItemRow["media"] }))).toBeNull();
  });

  it("keeps a row with no rating, year, creator, or cover", () => {
    const sparse = row();
    sparse.media.year = null;
    sparse.media.primary_creator = null;
    sparse.media.cover_url = null;

    const item = toLibraryItem(sparse);

    expect(item).not.toBeNull();
    expect(item?.rating).toBeNull();
    expect(item?.media.coverUrl).toBeNull();
  });
});
