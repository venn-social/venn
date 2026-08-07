import { describe, expect, it } from "vitest";
import type { MediaCandidate } from "@/lib/catalog/types";
import type { MediaRow } from "@/lib/media";
import {
  assembleShelves,
  type CandidateShelf,
  type RecommendationFeed
} from "@/lib/recommendations";

function mediaRow(id: string, title: string): MediaRow {
  return {
    id,
    kind: "movie",
    title,
    year: 2023,
    primary_creator: null,
    cover_url: null,
    external_id: null,
    external_source: null
  };
}

function candidate(externalId: string, title = "Candidate"): MediaCandidate {
  return {
    id: `tmdb:movie:${externalId}`,
    title,
    primaryCreator: null,
    year: null,
    coverUrl: null,
    overview: null,
    externalId,
    externalSource: "tmdb",
    kind: "movie"
  };
}

const emptyFeed: RecommendationFeed = { sections: [], seeds: [], excluded: [] };

describe("assembleShelves", () => {
  it("returns nothing when there is nothing", () => {
    expect(assembleShelves(emptyFeed, [])).toEqual([]);
  });

  it("drops a shelf with fewer than three items", () => {
    // Two covers under a heading reads as broken, not as a recommendation.
    const shelves = assembleShelves(emptyFeed, [
      { source: "trending", seedTitle: null, candidates: [candidate("1"), candidate("2")] }
    ]);
    expect(shelves).toEqual([]);
  });

  it("keeps a shelf with exactly three", () => {
    const shelves = assembleShelves(emptyFeed, [
      {
        source: "trending",
        seedTitle: null,
        candidates: [candidate("1"), candidate("2"), candidate("3")]
      }
    ]);
    expect(shelves).toHaveLength(1);
    expect(shelves[0].items).toHaveLength(3);
  });

  it("never shows something the viewer has already seen", () => {
    const feed: RecommendationFeed = {
      ...emptyFeed,
      excluded: [{ source: "tmdb", kind: "movie", id: "2" }]
    };
    const shelves = assembleShelves(feed, [
      {
        source: "trending",
        seedTitle: null,
        candidates: [candidate("1"), candidate("2"), candidate("3"), candidate("4")]
      }
    ]);

    expect(shelves[0].items).toHaveLength(3);
    expect(JSON.stringify(shelves)).not.toContain('"externalId":"2"');
  });

  it("excludes on kind as well as id", () => {
    // TMDB movie 5 and show 5 are different things; excluding the movie
    // must not hide the show.
    const feed: RecommendationFeed = {
      ...emptyFeed,
      excluded: [{ source: "tmdb", kind: "movie", id: "5" }]
    };
    const show: MediaCandidate = { ...candidate("5"), kind: "show", id: "tmdb:show:5" };
    const shelves = assembleShelves(feed, [
      {
        source: "trending",
        seedTitle: null,
        candidates: [show, candidate("6"), candidate("7")]
      }
    ]);

    expect(shelves[0].items).toHaveLength(3);
  });

  it("shows an item once, in the highest tier that has it", () => {
    const shelves = assembleShelves(emptyFeed, [
      {
        source: "similar",
        seedTitle: "Past Lives",
        candidates: [candidate("1"), candidate("2"), candidate("3")]
      },
      {
        source: "trending",
        seedTitle: null,
        candidates: [candidate("1"), candidate("4"), candidate("5"), candidate("6")]
      }
    ]);

    expect(shelves[0].items).toHaveLength(3);
    // "1" was taken by the similar shelf, so trending is down to three.
    expect(shelves[1].items).toHaveLength(3);
  });

  it("orders shelves by tier, not by arrival", () => {
    const feed: RecommendationFeed = {
      ...emptyFeed,
      sections: [
        { source: "followed", items: [mediaRow("a", "A"), mediaRow("b", "B"), mediaRow("c", "C")] },
        {
          source: "taste_twins",
          items: [mediaRow("d", "D"), mediaRow("e", "E"), mediaRow("f", "F")]
        }
      ]
    };
    const shelves = assembleShelves(feed, [
      {
        source: "trending",
        seedTitle: null,
        candidates: [candidate("1"), candidate("2"), candidate("3")]
      }
    ]);

    expect(shelves.map((shelf) => shelf.source)).toEqual(["taste_twins", "followed", "trending"]);
  });

  it("keeps at most four shelves", () => {
    const many: CandidateShelf[] = ["1", "2", "3", "4", "5"].map((seed) => ({
      source: "similar" as const,
      seedTitle: `Seed ${seed}`,
      candidates: [candidate(`${seed}a`), candidate(`${seed}b`), candidate(`${seed}c`)]
    }));

    expect(assembleShelves(emptyFeed, many)).toHaveLength(4);
  });

  it("caps a shelf at twelve items", () => {
    const candidates = Array.from({ length: 30 }, (_, index) => candidate(`c${index}`));
    const shelves = assembleShelves(emptyFeed, [
      { source: "trending", seedTitle: null, candidates }
    ]);

    expect(shelves[0].items).toHaveLength(12);
  });

  it("carries the seed title so the shelf can name what it is like", () => {
    const shelves = assembleShelves(emptyFeed, [
      {
        source: "similar",
        seedTitle: "Past Lives",
        candidates: [candidate("1"), candidate("2"), candidate("3")]
      }
    ]);

    expect(shelves[0].seedTitle).toBe("Past Lives");
  });

  it("drops a row whose media kind this client does not know", () => {
    // toMedia returns null for an unrecognised kind so a new kind shipped
    // server-side thins the shelf instead of breaking it. Three known rows
    // plus one unknown must yield three, not a crash.
    const unknown = { ...mediaRow("z", "Z"), kind: "podcast" as MediaRow["kind"] };
    const feed: RecommendationFeed = {
      ...emptyFeed,
      sections: [
        {
          source: "followed",
          items: [mediaRow("a", "A"), mediaRow("b", "B"), mediaRow("c", "C"), unknown]
        }
      ]
    };

    expect(assembleShelves(feed, [])[0].items).toHaveLength(3);
  });

  it("keeps a hand-typed row, which has no catalog identity to dedup on", () => {
    // These come from venn's own data, so there is nothing to exclude them
    // against — dropping them would silently thin the shelf.
    const feed: RecommendationFeed = {
      ...emptyFeed,
      sections: [
        {
          source: "followed",
          items: [mediaRow("a", "A"), mediaRow("b", "B"), mediaRow("c", "C")]
        }
      ]
    };

    expect(assembleShelves(feed, [])[0].items).toHaveLength(3);
  });
});
