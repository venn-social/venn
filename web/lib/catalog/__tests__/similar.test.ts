import { describe, expect, it } from "vitest";
import { toTrendingCandidates } from "@/lib/catalog/similar";

describe("toTrendingCandidates", () => {
  it("keeps movies and shows and labels each correctly", () => {
    // /trending/all/week mixes both, distinguished by media_type.
    const candidates = toTrendingCandidates({
      results: [
        { id: 1, media_type: "movie", title: "A Film", release_date: "2023-01-01" },
        { id: 2, media_type: "tv", name: "A Show", first_air_date: "2022-01-01" }
      ]
    });

    expect(candidates.map((candidate) => candidate.kind)).toEqual(["movie", "show"]);
    expect(candidates[0].id).toBe("tmdb:movie:1");
    expect(candidates[1].id).toBe("tmdb:show:2");
  });

  it("drops people, which that endpoint also returns", () => {
    // media_type "person" has no title and is not something you can log.
    const candidates = toTrendingCandidates({
      results: [
        { id: 3, media_type: "person", name: "Someone" },
        { id: 4, media_type: "movie", title: "A Film" }
      ]
    });

    expect(candidates).toHaveLength(1);
    expect(candidates[0].kind).toBe("movie");
  });

  it("survives a payload with no results", () => {
    expect(toTrendingCandidates({})).toEqual([]);
    expect(toTrendingCandidates(null)).toEqual([]);
  });
});
