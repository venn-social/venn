/**
 * The dry run on sample items: real-shaped catalog records go through the
 * whole pure pipeline, and every row that comes out must be one the
 * database will accept.
 */
import { describe, expect, it } from "vitest";
import { buildRows } from "@/lib/taste/build";
import { musicBrainzFeatures } from "@/lib/taste/providers/musicBrainz";
import { openLibraryFeatures } from "@/lib/taste/providers/openLibrary";
import { tmdbFeatures } from "@/lib/taste/providers/tmdb";
import { EXTRACTOR_VERSION, featureRowProblems } from "@/lib/taste/record";
import { indexMappings, seedMappings } from "@/lib/taste/taxonomy";
import {
  MB_BLUE_GROUP,
  MB_BLUE_RELEASE,
  OL_KLARA,
  TMDB_BREAKING_BAD,
  TMDB_PAST_LIVES
} from "@/lib/taste/__tests__/fixtures";

const mappings = indexMappings(seedMappings());
const samples = [
  ["past-lives", tmdbFeatures(TMDB_PAST_LIVES, "movie")],
  ["breaking-bad", tmdbFeatures(TMDB_BREAKING_BAD, "show")],
  ["klara", openLibraryFeatures(OL_KLARA)],
  ["blue", musicBrainzFeatures(MB_BLUE_GROUP, MB_BLUE_RELEASE)]
] as const;

describe("buildRows — dry run on sample items", () => {
  it.each(samples)("%s produces a valid media_features row", (id, extracted) => {
    const { features } = buildRows(id, extracted, mappings, []);
    expect(featureRowProblems(features)).toEqual([]);
    expect(features.extractor_version).toBe(EXTRACTOR_VERSION);
    expect(features.decade).toBe(
      features.year === null ? null : features.year - (features.year % 10)
    );
  });

  it.each(samples)("%s produces taxonomy weights the database accepts", (id, extracted) => {
    const { taxonomy } = buildRows(id, extracted, mappings, []);
    expect(taxonomy.length).toBeGreaterThan(0);
    for (const { weight } of taxonomy) {
      expect(weight).toBeGreaterThan(0);
      expect(weight).toBeLessThanOrEqual(1);
    }
  });

  it("finds the shared nodes that make a cross-media recommendation explainable", () => {
    const nodes = (index: number) =>
      buildRows("x", samples[index][1], mappings, []).taxonomy.map((entry) => entry.node);
    // Past Lives (film) and Klara and the Sun (novel) meet at coming-of-age.
    expect(nodes(0)).toContain("coming-of-age");
    expect(nodes(2)).toContain("coming-of-age");
    expect(nodes(2)).toContain("science-fiction");
    expect(nodes(3)).toEqual(
      expect.arrayContaining(["folk", "singer-songwriter", "folk-classical"])
    );
  });

  it("places each sample on the commitment scale", () => {
    const commitment = (index: number) =>
      buildRows("x", samples[index][1], mappings, []).features.commitment;
    expect(commitment(0)).toBeGreaterThan(0.5); // 106 min film
    expect(commitment(1)).toBeGreaterThan(0.9); // 62 episodes
    expect(commitment(3)).toBeGreaterThan(0.4); // 42 min album
  });
});

describe("featureRowProblems", () => {
  it("names every rule a row breaks", () => {
    expect(
      featureRowProblems({
        media_id: "x",
        year: 1971,
        decade: 1980,
        length_raw: -1,
        commitment: 2,
        language: "eng",
        countries: ["usa"],
        // @ts-expect-error — the point is a tag outside the vocabulary
        sound_tags: ["kazoo"],
        extractor_version: 1
      })
    ).toHaveLength(6);
  });
});
