import { describe, expect, it } from "vitest";
import { regionFrom, sourceUrlFor } from "@/lib/catalog/detail";
import { toAlbumDetail } from "@/lib/catalog/musicBrainz";
import { toBookDetail } from "@/lib/catalog/openLibrary";
import { toMovieDetail } from "@/lib/catalog/tmdb";

describe("regionFrom", () => {
  it("prefers the edge geo header", () => {
    const headers = new Headers({ "x-vercel-ip-country": "fr", "accept-language": "en-US" });
    expect(regionFrom(headers)).toBe("FR");
  });

  it("falls back to the Accept-Language region in local dev", () => {
    expect(regionFrom(new Headers({ "accept-language": "en-US,en;q=0.9" }))).toBe("US");
  });

  it("defaults to GB when nothing says otherwise", () => {
    expect(regionFrom(new Headers())).toBe("GB");
  });

  it("ignores a malformed geo header rather than trusting it", () => {
    expect(regionFrom(new Headers({ "x-vercel-ip-country": "XXXX" }))).toBe("GB");
  });
});

describe("sourceUrlFor", () => {
  it("links a movie and a show to their different TMDB paths", () => {
    expect(sourceUrlFor("tmdb", "movie", "1")).toBe("https://www.themoviedb.org/movie/1");
    expect(sourceUrlFor("tmdb", "show", "1")).toBe("https://www.themoviedb.org/tv/1");
  });

  it("links books and albums to their own catalogs", () => {
    expect(sourceUrlFor("openlibrary", "book", "OL1W")).toBe(
      "https://openlibrary.org/works/OL1W"
    );
    expect(sourceUrlFor("musicbrainz", "album", "mbid")).toBe(
      "https://musicbrainz.org/release-group/mbid"
    );
  });
});

describe("toMovieDetail", () => {
  const payload = {
    overview: "Two friends reunite.",
    runtime: 106,
    genres: [{ name: "Drama" }, { name: "Romance" }],
    release_date: "2023-06-02",
    vote_average: 7.8,
    credits: {
      cast: [{ name: "Greta Lee", character: "Nora" }],
      crew: [
        { name: "Celine Song", job: "Director" },
        { name: "Someone Else", job: "Gaffer" }
      ]
    },
    "watch/providers": {
      results: {
        GB: {
          link: "https://tmdb.example/watch",
          flatrate: [{ provider_name: "Netflix", logo_path: "/n.jpg" }],
          rent: [{ provider_name: "Netflix" }, { provider_name: "Apple TV" }]
        },
        US: { flatrate: [{ provider_name: "Hulu" }] }
      }
    }
  };

  it("maps the record, cast, and director", () => {
    const detail = toMovieDetail(payload, "GB");

    expect(detail.overview).toBe("Two friends reunite.");
    expect(detail.runtime).toBe(106);
    expect(detail.genres).toEqual(["Drama", "Romance"]);
    expect(detail.credits[0]).toEqual({ name: "Greta Lee", role: "Nora" });
    expect(detail.creators.map((person) => person.name)).toEqual(["Celine Song"]);
  });

  it("keeps only the crew credit that answers 'who made this'", () => {
    // A full crew list runs to hundreds of names; the gaffer isn't the
    // answer anyone is looking for on a detail page.
    expect(toMovieDetail(payload, "GB").creators).toHaveLength(1);
  });

  it("returns availability for the requested region only", () => {
    const detail = toMovieDetail(payload, "GB");
    expect(detail.watchLinks.map((link) => link.provider)).toEqual(["Netflix", "Apple TV"]);
    expect(detail.watchRegion).toBe("GB");
  });

  it("lists a provider once, under the cheapest way to watch", () => {
    // Netflix appears under both flatrate and rent here. Streaming is the
    // useful answer; showing it twice would imply you must pay.
    const netflix = toMovieDetail(payload, "GB").watchLinks.filter(
      (link) => link.provider === "Netflix"
    );
    expect(netflix).toHaveLength(1);
    expect(netflix[0].kind).toBe("stream");
  });

  it("returns no links for a region with no availability", () => {
    expect(toMovieDetail(payload, "JP").watchLinks).toEqual([]);
  });

  it("survives an empty payload", () => {
    const detail = toMovieDetail({}, "GB");
    expect(detail.overview).toBeNull();
    expect(detail.credits).toEqual([]);
    expect(detail.watchLinks).toEqual([]);
  });
});

describe("toBookDetail", () => {
  it("maps a description given as an object", () => {
    const detail = toBookDetail({ description: { value: "A house of halls." } }, ["Susanna Clarke"]);
    expect(detail.overview).toBe("A house of halls.");
    expect(detail.creators).toEqual([{ name: "Susanna Clarke", role: "Author" }]);
  });

  it("accepts a description given as a bare string", () => {
    // Older OpenLibrary records use the string form.
    expect(toBookDetail({ description: "Plain text." }, []).overview).toBe("Plain text.");
  });

  it("caps the subject list, since records carry dozens", () => {
    const subjects = Array.from({ length: 30 }, (_, index) => `Subject ${index}`);
    expect(toBookDetail({ subjects }, []).genres).toHaveLength(8);
  });
});

describe("toAlbumDetail", () => {
  it("maps the artist and orders tags by how many people applied them", () => {
    const detail = toAlbumDetail({
      "artist-credit": [{ artist: { name: "Radiohead" } }],
      "first-release-date": "2016-05-08",
      tags: [
        { name: "rock", count: 2 },
        { name: "art rock", count: 9 }
      ]
    });

    expect(detail.creators).toEqual([{ name: "Radiohead", role: "Artist" }]);
    expect(detail.genres).toEqual(["art rock", "rock"]);
    expect(detail.releaseDate).toBe("2016-05-08");
  });

  it("leaves the description null rather than inventing one", () => {
    // MusicBrainz is a structured database, not a review site.
    expect(toAlbumDetail({ "artist-credit": [{ artist: { name: "X" } }] }).overview).toBeNull();
  });
});
