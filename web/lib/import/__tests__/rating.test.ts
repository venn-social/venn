import { describe, expect, it } from "vitest";
import { parseStars, starsToChoice, starsToPost } from "@/lib/import/rating";

describe("starsToChoice", () => {
  it.each([
    [5, "love"],
    [4.5, "love"],
    [4, "like"],
    [3.5, "like"],
    [3, null],
    [2.5, null],
    [2, "dislike"],
    [0.5, "dislike"]
  ])("maps %s stars to %s", (stars, choice) => {
    expect(starsToChoice(stars)).toBe(choice);
  });

  it("treats no rating and zero as no sentiment", () => {
    expect(starsToChoice(null)).toBeNull();
    expect(starsToChoice(0)).toBeNull();
  });
});

describe("starsToPost", () => {
  it("uses the composer's own mapping", () => {
    expect(starsToPost(5)).toEqual({ action: "rated", rating: 5 });
    expect(starsToPost(4)).toEqual({ action: "rated", rating: 3 });
    expect(starsToPost(1)).toEqual({ action: "rated", rating: 1 });
    expect(starsToPost(3)).toEqual({ action: "logged", rating: null });
  });
});

describe("parseStars", () => {
  it("reads half-star values", () => {
    expect(parseStars("4.5")).toBe(4.5);
    expect(parseStars(" 3 ")).toBe(3);
  });

  it("returns null for empty, zero, out-of-range and junk cells", () => {
    expect(parseStars(undefined)).toBeNull();
    expect(parseStars("")).toBeNull();
    expect(parseStars("0")).toBeNull();
    expect(parseStars("6")).toBeNull();
    expect(parseStars("five")).toBeNull();
  });
});
