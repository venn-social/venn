import { describe, expect, it } from "vitest";
import { candidateId, type MediaCandidate } from "@/lib/catalog/types";
import { bestMatch, normalizeTitle } from "@/lib/import/match";

function film(id: string, title: string, year: number | null): MediaCandidate {
  return {
    id: candidateId("tmdb", "movie", id),
    title,
    year,
    primaryCreator: null,
    coverUrl: null,
    overview: null,
    externalId: id,
    externalSource: "tmdb",
    kind: "movie"
  };
}

describe("normalizeTitle", () => {
  it("ignores case, accents, punctuation and a leading article", () => {
    expect(normalizeTitle("The Grand Budapest Hotel")).toBe("grand budapest hotel");
    expect(normalizeTitle("Amélie")).toBe("amelie");
    expect(normalizeTitle("Mission: Impossible – Fallout")).toBe("mission impossible fallout");
  });

  it("treats & and 'and' alike", () => {
    expect(normalizeTitle("Fast & Furious")).toBe(normalizeTitle("Fast and Furious"));
  });

  it("keeps non-Latin titles", () => {
    expect(normalizeTitle("千と千尋の神隠し")).toBe("千と千尋の神隠し");
  });
});

describe("bestMatch", () => {
  const results = [
    film("1", "Dune", 2021),
    film("2", "Dune", 1984),
    film("3", "Dune: Part Two", 2024)
  ];

  it("prefers the same title in the same year", () => {
    expect(bestMatch("Dune", 1984, results)?.externalId).toBe("2");
  });

  it("accepts a year off by one", () => {
    expect(bestMatch("Dune", 1985, results)?.externalId).toBe("2");
  });

  it("falls back to a containing title in the same year", () => {
    expect(bestMatch("Dune Part Two", 2024, results)?.externalId).toBe("3");
  });

  it("takes the most relevant same-title result when there is no year", () => {
    expect(bestMatch("dune", null, results)?.externalId).toBe("1");
  });

  it("refuses to guess when nothing matches", () => {
    expect(bestMatch("Arrival", 2016, results)).toBeNull();
    expect(bestMatch("Dune", 1999, results)).toBeNull();
    expect(bestMatch("", 2021, results)).toBeNull();
  });
});
