import { describe, expect, it } from "vitest";
import { parseLetterboxdExport } from "@/lib/import/letterboxd";

const watched = `Date,Name,Year,Letterboxd URI
2023-01-02,Heat,1995,https://boxd.it/a
2023-02-03,Cats,2019,https://boxd.it/b
2023-03-04,Paddington 2,2017,https://boxd.it/c
`;

const diary = `Date,Name,Year,Letterboxd URI,Rating,Rewatch,Tags,Watched Date
2023-01-03,Heat,1995,https://boxd.it/d1,4,,,2023-01-02
2024-05-01,Heat,1995,https://boxd.it/d2,5,Yes,,2024-04-30
2023-02-04,Cats,2019,https://boxd.it/d3,,,,2023-02-03
`;

const ratings = `Date,Name,Year,Letterboxd URI,Rating
2023-02-04,Cats,2019,https://boxd.it/b,1
2023-03-05,Paddington 2,2017,https://boxd.it/c,4.5
2023-06-01,"Crouching Tiger, Hidden Dragon",2000,https://boxd.it/e,3
`;

const watchlist = `Date,Name,Year,Letterboxd URI
2022-12-01,Heat,1995,https://boxd.it/a
2022-12-02,Past Lives,2023,https://boxd.it/f
`;

function byTitle(text: Partial<Record<string, string>>) {
  const { entries, problems } = parseLetterboxdExport(text);
  return { map: new Map(entries.map((e) => [e.title, e])), entries, problems };
}

describe("parseLetterboxdExport", () => {
  const { map, entries, problems } = byTitle({
    "watched.csv": watched,
    "diary.csv": diary,
    "ratings.csv": ratings,
    "watchlist.csv": watchlist
  });

  it("produces one entry per film across all files", () => {
    expect(entries).toHaveLength(5);
    expect(problems).toEqual([]);
  });

  it("uses the newest diary rating when ratings.csv has none", () => {
    expect(map.get("Heat")).toMatchObject({ action: "rated", rating: 5, consumedAt: "2024-04-30" });
  });

  it("prefers the current rating in ratings.csv", () => {
    expect(map.get("Cats")).toMatchObject({ action: "rated", rating: 1, year: 2019 });
    expect(map.get("Paddington 2")).toMatchObject({ action: "rated", rating: 5 });
  });

  it("logs a middling rating without a sentiment", () => {
    expect(map.get("Crouching Tiger, Hidden Dragon")).toMatchObject({
      action: "logged",
      rating: null,
      consumedAt: "2023-06-01"
    });
  });

  it("saves watchlist-only films and lets watching win over the watchlist", () => {
    expect(map.get("Past Lives")).toMatchObject({
      action: "saved",
      rating: null,
      consumedAt: "2022-12-02"
    });
    expect(map.get("Heat")?.action).toBe("rated");
  });

  it("marks every entry as a movie with no book fields", () => {
    for (const entry of entries) {
      expect(entry).toMatchObject({ kind: "movie", creator: null, isbn: null });
    }
  });

  it("reports rows with no usable title, with their line numbers", () => {
    const result = parseLetterboxdExport({
      "watched.csv": `Date,Name,Year\n2023-01-01,,2000\n2023-01-01,${"x".repeat(101)},2000\n`
    });
    expect(result.entries).toEqual([]);
    expect(result.problems).toEqual([
      { file: "watched.csv", line: 2, reason: "missingTitle" },
      { file: "watched.csv", line: 3, reason: "titleTooLong" }
    ]);
  });

  it("keeps same-named films from different years apart", () => {
    const result = parseLetterboxdExport({
      "watched.csv": "Date,Name,Year\n2023-01-01,Dune,1984\n2023-01-02,Dune,2021\n"
    });
    expect(result.entries.map((e) => e.year).sort()).toEqual([1984, 2021]);
  });

  it("is unaffected by files it does not read and by missing files", () => {
    expect(parseLetterboxdExport({}).entries).toEqual([]);
  });

  it("ignores malformed dates and years", () => {
    const result = parseLetterboxdExport({
      "watched.csv": "Date,Name,Year\n01/02/2023,Heat,abc\n"
    });
    expect(result.entries[0]).toMatchObject({ year: null, consumedAt: null, action: "logged" });
  });
});
