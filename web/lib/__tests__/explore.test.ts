import { describe, expect, it } from "vitest";
import { toMediaList } from "@/lib/explore";

describe("toMediaList", () => {
  it("maps rows into domain media", () => {
    const media = toMediaList([
      {
        id: "m1",
        kind: "movie",
        title: "Past Lives",
        year: 2023,
        primary_creator: "Celine Song",
        cover_url: null
      }
    ]);

    expect(media).toHaveLength(1);
    expect(media[0].title).toBe("Past Lives");
    expect(media[0].kind).toBe("movie");
  });

  it("drops rows with an unknown kind rather than breaking the grid", () => {
    const media = toMediaList([
      { id: "m1", kind: "hologram", title: "Weird" },
      { id: "m2", kind: "book", title: "Fine" }
    ]);

    expect(media.map((item) => item.title)).toEqual(["Fine"]);
  });

  it("returns an empty array for null or a non-array", () => {
    expect(toMediaList(null)).toEqual([]);
    expect(toMediaList(undefined)).toEqual([]);
    expect(toMediaList({})).toEqual([]);
  });
});
