import { describe, expect, it } from "vitest";
import { musicBrainzFeatures } from "@/lib/taste/providers/musicBrainz";
import { openLibraryFeatures } from "@/lib/taste/providers/openLibrary";
import { tmdbFeatures } from "@/lib/taste/providers/tmdb";
import {
  MB_BLUE_GROUP,
  MB_BLUE_RELEASE,
  OL_KLARA,
  TMDB_BREAKING_BAD,
  TMDB_PAST_LIVES
} from "@/lib/taste/__tests__/fixtures";

describe("tmdbFeatures — movie", () => {
  const features = tmdbFeatures(TMDB_PAST_LIVES, "movie");

  it("reads year, runtime, language and production countries", () => {
    expect(features).toMatchObject({
      kind: "movie",
      year: 2023,
      lengthRaw: 106,
      language: "en",
      countries: ["US", "KR"]
    });
  });

  it("credits the director once per role and the top five cast in billing order", () => {
    const roles = features.people.map((p) => `${p.name}:${p.role}:${p.billing ?? "-"}`);
    expect(roles).toEqual([
      "Celine Song:director:-",
      "Celine Song:screenwriter:-",
      "Christopher Bear:composer:-",
      "Greta Lee:cast:1",
      "Teo Yoo:cast:2",
      "John Magaro:cast:3",
      "Extra Four:cast:4",
      "Extra Five:cast:5"
    ]);
    expect(features.people[0].ids).toEqual({ tmdb: "2340979" });
  });

  it("reports genre ids and keyword names as terms", () => {
    expect(features.terms).toContainEqual({ source: "tmdb_genre", key: "18" });
    expect(features.terms).toContainEqual({ source: "tmdb_keyword", key: "coming of age" });
  });
});

describe("tmdbFeatures — show", () => {
  const features = tmdbFeatures(TMDB_BREAKING_BAD, "show");

  it("measures a show by its whole run", () => {
    expect(features.lengthRaw).toBe(45 * 62);
    expect(features.year).toBe(2008);
    expect(features.countries).toEqual(["US"]);
  });

  it("credits the creator and reads TV keywords", () => {
    expect(features.people[0]).toMatchObject({ name: "Vince Gilligan", role: "tv_creator" });
    expect(features.terms).toContainEqual({ source: "tmdb_keyword", key: "neo-noir" });
  });

  it("treats TMDB's missing values as unknown", () => {
    const sparse = tmdbFeatures({ original_language: "xx", runtime: 0, release_date: "" }, "movie");
    expect(sparse).toMatchObject({
      year: null,
      lengthRaw: null,
      language: null,
      people: [],
      terms: []
    });
  });
});

describe("openLibraryFeatures", () => {
  const features = openLibraryFeatures(OL_KLARA);

  it("reads year, median pages and a single edition language", () => {
    expect(features).toMatchObject({
      kind: "book",
      year: 2021,
      lengthRaw: 303,
      language: "en",
      countries: []
    });
  });

  it("credits authors with their Open Library ids", () => {
    expect(features.people).toEqual([
      { name: "Kazuo Ishiguro", role: "author", billing: null, ids: { openlibrary: "OL2627906A" } }
    ]);
  });

  it("drops shelving noise from subjects", () => {
    expect(features.terms.map((t) => t.key)).not.toContain(
      "nyt:combined-print-and-e-book-fiction=2021-03-21"
    );
    expect(features.terms).toContainEqual({
      source: "openlibrary_subject",
      key: "Science Fiction"
    });
  });

  it("leaves language unknown when editions disagree", () => {
    expect(openLibraryFeatures({ ...OL_KLARA, language: ["eng", "fre"] }).language).toBeNull();
  });
});

describe("musicBrainzFeatures", () => {
  const features = musicBrainzFeatures(MB_BLUE_GROUP, MB_BLUE_RELEASE);

  it("reads year from the group and length, country and language from the release", () => {
    expect(features).toMatchObject({
      kind: "album",
      year: 1971,
      lengthRaw: 42.2,
      language: "en",
      countries: ["US"]
    });
  });

  it("credits the primary artist", () => {
    expect(features.people).toEqual([
      {
        name: "Joni Mitchell",
        role: "primary_artist",
        billing: null,
        ids: { musicbrainz: "5c5c1d6e-2b4a-4c3e-9f8b-1f8a3c2b7d10" }
      }
    ]);
  });

  it("keeps voted genres and tags, and maps the sound vocabulary", () => {
    const keys = features.terms.map((t) => t.key);
    expect(keys).toEqual(["folk", "singer-songwriter", "acoustic guitar", "piano"]);
    // "mellow" has one vote: an opinion, not a consensus.
    expect(features.soundTags).toEqual(["guitar", "piano"]);
  });

  it("gives no length when a track's is missing, rather than understating it", () => {
    const partial = {
      ...MB_BLUE_RELEASE,
      media: [{ tracks: [{ length: 100000 }, { length: null }] }]
    };
    expect(musicBrainzFeatures(MB_BLUE_GROUP, partial).lengthRaw).toBeNull();
    expect(musicBrainzFeatures(MB_BLUE_GROUP, null).lengthRaw).toBeNull();
  });

  it("ignores MusicBrainz's pseudo-countries", () => {
    expect(
      musicBrainzFeatures(MB_BLUE_GROUP, { ...MB_BLUE_RELEASE, country: "XW" }).countries
    ).toEqual([]);
  });
});
