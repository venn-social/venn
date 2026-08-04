import { describe, expect, it } from "vitest";
import { candidateId, yearFrom } from "@/lib/catalog/types";

describe("yearFrom", () => {
  it("parses a year from a full ISO date", () => {
    expect(yearFrom("2023-06-02")).toBe(2023);
  });

  it("parses a year from a year-month string", () => {
    expect(yearFrom("2016-05")).toBe(2016);
  });

  it("parses a bare year", () => {
    expect(yearFrom("1999")).toBe(1999);
  });

  it("returns null for a string too short to hold a year", () => {
    expect(yearFrom("99")).toBeNull();
  });

  it("returns null for null, undefined, and empty", () => {
    expect(yearFrom(null)).toBeNull();
    expect(yearFrom(undefined)).toBeNull();
    expect(yearFrom("")).toBeNull();
  });

  it("returns null when the first four characters are not a number", () => {
    expect(yearFrom("n/a-01-01")).toBeNull();
  });
});

describe("candidateId", () => {
  it("namespaces the external id by its source", () => {
    // Two providers can hand back the same raw id; the triple is unique.
    expect(candidateId("tmdb", "movie", "123")).toBe("tmdb:movie:123");
    expect(candidateId("openlibrary", "book", "123")).toBe("openlibrary:book:123");
  });

  it("distinguishes a movie from a show with the same TMDB id", () => {
    // TMDB numbers film and television independently, so this collision is
    // real — and visible in the All category, which searches both.
    expect(candidateId("tmdb", "movie", "123")).not.toBe(candidateId("tmdb", "show", "123"));
  });
});
