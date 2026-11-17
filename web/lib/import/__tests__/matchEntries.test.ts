import { describe, expect, it } from "vitest";
import { candidateId, type MediaCandidate } from "@/lib/catalog/types";
import { matchEntries, type MatchableEntry } from "@/lib/import/matchEntries";

function film(id: string, title: string, year: number): MediaCandidate {
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

const row = (title: string, year: number | null): MatchableEntry => ({
  kind: "movie",
  title,
  year,
  creator: null,
  isbn: null
});

describe("matchEntries", () => {
  it("returns one result per entry, in order", async () => {
    const catalog: Record<string, MediaCandidate[]> = {
      Heat: [film("1", "Heat", 1995)],
      Arrival: [film("2", "Arrival", 2016)]
    };
    const matches = await matchEntries(
      [row("Arrival", 2016), row("Unknown", 2000), row("Heat", 1995)],
      { search: async (_kind, query) => catalog[query] ?? [] }
    );
    expect(matches.map((m) => m?.externalId ?? null)).toEqual(["2", null, "1"]);
  });

  it("treats one failed lookup as unmatched without failing the batch", async () => {
    const matches = await matchEntries([row("Boom", 2000), row("Heat", 1995)], {
      search: async (_kind, query) => {
        if (query === "Boom") throw new Error("TMDB 500");
        return [film("1", "Heat", 1995)];
      }
    });
    expect(matches.map((m) => m?.externalId ?? null)).toEqual([null, "1"]);
  });
});
