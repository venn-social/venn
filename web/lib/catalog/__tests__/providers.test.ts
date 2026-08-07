import { describe, expect, it } from "vitest";
import { toAlbumCandidates } from "@/lib/catalog/musicBrainz";
import { toBookCandidates } from "@/lib/catalog/openLibrary";
import { toMovieCandidates, toShowCandidates } from "@/lib/catalog/tmdb";

describe("toMovieCandidates", () => {
  it("maps a complete movie", () => {
    const [movie] = toMovieCandidates({
      results: [
        {
          id: 12345,
          title: "Past Lives",
          release_date: "2023-06-02",
          poster_path: "/abc.jpg",
          overview: "Two friends reunite."
        }
      ]
    });

    expect(movie.title).toBe("Past Lives");
    expect(movie.year).toBe(2023);
    expect(movie.kind).toBe("movie");
    expect(movie.externalSource).toBe("tmdb");
    expect(movie.externalId).toBe("12345");
    expect(movie.coverUrl).toBe("https://image.tmdb.org/t/p/w500/abc.jpg");
    expect(movie.overview).toBe("Two friends reunite.");
  });

  it("handles a movie with no poster, date, or overview", () => {
    const [movie] = toMovieCandidates({
      results: [{ id: 1, title: "Untitled", release_date: "", poster_path: null }]
    });

    expect(movie.coverUrl).toBeNull();
    expect(movie.year).toBeNull();
    expect(movie.overview).toBeNull();
  });

  it("returns an empty array when results is missing or not an array", () => {
    expect(toMovieCandidates({})).toEqual([]);
    expect(toMovieCandidates({ results: null })).toEqual([]);
    expect(toMovieCandidates(null)).toEqual([]);
  });

  it("skips entries missing an id or title rather than emitting junk rows", () => {
    const candidates = toMovieCandidates({
      results: [{ id: 1 }, { title: "No id" }, { id: 2, title: "Fine" }]
    });
    expect(candidates.map((candidate) => candidate.title)).toEqual(["Fine"]);
  });
});

describe("toShowCandidates", () => {
  it("reads name and first_air_date rather than title and release_date", () => {
    // TMDB uses different field names for TV — mixing them up yields
    // untitled, undated results.
    const [show] = toShowCandidates({
      results: [{ id: 99, name: "Severance", first_air_date: "2022-02-18", poster_path: "/s.jpg" }]
    });

    expect(show.title).toBe("Severance");
    expect(show.year).toBe(2022);
    expect(show.kind).toBe("show");
  });
});

describe("toBookCandidates", () => {
  it("maps a complete book", () => {
    const [book] = toBookCandidates({
      docs: [
        {
          key: "/works/OL123W",
          title: "Piranesi",
          author_name: ["Susanna Clarke", "Someone Else"],
          first_publish_year: 2020,
          cover_i: 987,
          first_sentence: { value: "The Halls are endless." }
        }
      ]
    });

    expect(book.title).toBe("Piranesi");
    // Only the first author, matching OpenLibraryService.
    expect(book.primaryCreator).toBe("Susanna Clarke");
    expect(book.year).toBe(2020);
    expect(book.externalId).toBe("OL123W");
    // -L, not -M: a medium cover is 180px and renders smaller than the tile
    // it sits in, so books looked soft next to TMDB posters.
    expect(book.coverUrl).toBe("https://covers.openlibrary.org/b/id/987-L.jpg");
    expect(book.overview).toBe("The Halls are endless.");
    expect(book.kind).toBe("book");
  });

  it("strips only the /works/ prefix and passes a bare key through", () => {
    const [bare] = toBookCandidates({ docs: [{ key: "OL9W", title: "Bare" }] });
    expect(bare.externalId).toBe("OL9W");
  });

  it("handles a book with no cover, author, year, or sentence", () => {
    const [sparse] = toBookCandidates({ docs: [{ key: "/works/OL1W", title: "Sparse" }] });

    expect(sparse.coverUrl).toBeNull();
    expect(sparse.primaryCreator).toBeNull();
    expect(sparse.year).toBeNull();
    expect(sparse.overview).toBeNull();
  });

  it("accepts first_sentence given as a plain string", () => {
    // OpenLibrary returns either {value} or a bare string depending on the record.
    const [book] = toBookCandidates({
      docs: [{ key: "/works/OL2W", title: "Stringy", first_sentence: "Just a string." }]
    });
    expect(book.overview).toBe("Just a string.");
  });
});

describe("toAlbumCandidates", () => {
  it("maps a complete release group", () => {
    const [album] = toAlbumCandidates({
      "release-groups": [
        {
          id: "mbid-1",
          title: "A Moon Shaped Pool",
          "artist-credit": [{ name: "Radiohead" }],
          "first-release-date": "2016-05-08"
        }
      ]
    });

    expect(album.title).toBe("A Moon Shaped Pool");
    expect(album.primaryCreator).toBe("Radiohead");
    expect(album.year).toBe(2016);
    expect(album.kind).toBe("album");
    expect(album.coverUrl).toBe("https://coverartarchive.org/release-group/mbid-1/front-500");
    // MusicBrainz surfaces no description.
    expect(album.overview).toBeNull();
  });

  it("handles a release group with no artist credit or date", () => {
    const [album] = toAlbumCandidates({
      "release-groups": [{ id: "mbid-2", title: "Untitled" }]
    });

    expect(album.primaryCreator).toBeNull();
    expect(album.year).toBeNull();
  });

  it("returns an empty array when release-groups is absent", () => {
    expect(toAlbumCandidates({})).toEqual([]);
  });
});
