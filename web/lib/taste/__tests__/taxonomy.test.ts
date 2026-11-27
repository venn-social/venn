import { describe, expect, it } from "vitest";
import {
  TAXONOMY_NODES,
  TMDB_GENRES,
  indexMappings,
  labelKey,
  normalizeTerm,
  seedMappings,
  taxonomyVector
} from "@/lib/taste/taxonomy";

const SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const mappings = indexMappings(seedMappings());

describe("taxonomy tree", () => {
  it("has the spec's 18 families, each naming itself", () => {
    const families = TAXONOMY_NODES.filter((node) => node.parent === null);
    expect(families).toHaveLength(18);
    for (const family of families) expect(family.family).toBe(family.slug);
  });

  it("uses unique slugs the database accepts, with every parent present", () => {
    const slugs = TAXONOMY_NODES.map((node) => node.slug);
    expect(new Set(slugs).size).toBe(slugs.length);
    for (const node of TAXONOMY_NODES) {
      expect(node.slug).toMatch(SLUG);
      if (node.parent) expect(slugs).toContain(node.parent);
    }
  });

  it("scopes the four music families, and only them, to albums", () => {
    const scoped = TAXONOMY_NODES.filter((node) => node.kindScope !== null && node.parent === null);
    expect(scoped.map((node) => node.slug).sort()).toEqual([
      "electronic",
      "folk-classical",
      "rock",
      "soul-hiphop"
    ]);
    expect(TAXONOMY_NODES.find((node) => node.slug === "shoegaze")?.kindScope).toEqual(["album"]);
  });

  it("derives copy keys, never English", () => {
    expect(labelKey("folk-horror")).toBe("taxonomy.folk_horror");
  });
});

describe("TMDB genres", () => {
  it("accounts for all 27 movie and TV genre ids", () => {
    expect(Object.keys(TMDB_GENRES)).toHaveLength(27);
  });

  it("only maps onto nodes that exist, with weights in (0, 1]", () => {
    const slugs = new Set(TAXONOMY_NODES.map((node) => node.slug));
    for (const row of seedMappings()) {
      expect(slugs.has(row.node)).toBe(true);
      expect(row.weight).toBeGreaterThan(0);
      expect(row.weight).toBeLessThanOrEqual(1);
    }
  });

  it("splits Sci-Fi & Fantasy evenly, as the spec specifies", () => {
    expect(TMDB_GENRES["10765"].nodes).toEqual([
      ["speculative", 0.5],
      ["fantasy", 0.5]
    ]);
  });
});

describe("normalizeTerm", () => {
  it.each([
    ["Film Noir", "film-noir"],
    ["R&B", "r-and-b"],
    ["  Coming of age ", "coming-of-age"],
    ["Fiction, science fiction, general", "fiction-science-fiction-general"],
    ["Café", "cafe"]
  ])("%s → %s", (input, output) => {
    expect(normalizeTerm(input)).toBe(output);
  });
});

describe("taxonomyVector", () => {
  it("maps by id for genres and by normalised name elsewhere", () => {
    const vector = taxonomyVector(
      [
        { source: "tmdb_genre", key: "80" },
        { source: "tmdb_keyword", key: "Film Noir" }
      ],
      "movie",
      mappings
    );
    expect([...vector.keys()].sort()).toEqual(["crime", "noir"]);
  });

  it("passes half a child's weight to its parent, then L2-normalises", () => {
    const vector = taxonomyVector([{ source: "tmdb_keyword", key: "heist" }], "movie", mappings);
    // heist 1, crime 0.5 → normalised by sqrt(1.25)
    expect(vector.get("heist")).toBeCloseTo(1 / Math.sqrt(1.25), 6);
    expect(vector.get("crime")).toBeCloseTo(0.5 / Math.sqrt(1.25), 6);
    const norm = Math.sqrt([...vector.values()].reduce((sum, w) => sum + w * w, 0));
    expect(norm).toBeCloseTo(1, 6);
  });

  it("never gives a novel an album-only node", () => {
    const vector = taxonomyVector(
      [{ source: "openlibrary_subject", key: "Shoegaze" }],
      "book",
      mappings
    );
    expect(vector.size).toBe(0);
    const album = taxonomyVector(
      [{ source: "musicbrainz_genre", key: "Shoegaze" }],
      "album",
      mappings
    );
    expect([...album.keys()].sort()).toEqual(["rock", "shoegaze"]);
  });

  it("counts a term reported twice once, and ignores unmapped terms", () => {
    const once = taxonomyVector([{ source: "musicbrainz_tag", key: "jazz" }], "album", mappings);
    const twice = taxonomyVector(
      [
        { source: "musicbrainz_tag", key: "jazz" },
        { source: "musicbrainz_tag", key: "Jazz" },
        { source: "musicbrainz_tag", key: "seen live" }
      ],
      "album",
      mappings
    );
    expect(twice).toEqual(once);
  });

  it("is empty, not an error, when nothing maps", () => {
    expect(taxonomyVector([{ source: "tmdb_genre", key: "10770" }], "movie", mappings).size).toBe(
      0
    );
  });
});
