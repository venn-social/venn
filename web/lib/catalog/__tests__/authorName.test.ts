import { describe, expect, it } from "vitest";
import {
  flippingSurnameFirst,
  isLatinScript,
  preferredAuthorName
} from "@/lib/catalog/authorName";

/** Mirrors ios/VennTests/Utils/AuthorNameTests.swift case for case. */

describe("isLatinScript", () => {
  it("accepts plain English", () => {
    expect(isLatinScript("Albert Camus")).toBe(true);
  });

  it("accepts diacritics — the test is script, not ASCII", () => {
    // Süskind and Céline are Latin. Stripping them would be a regression
    // dressed up as a fix.
    expect(isLatinScript("Patrick Süskind")).toBe(true);
    expect(isLatinScript("Louis-Ferdinand Céline")).toBe(true);
    expect(isLatinScript("Þórbergur Þórðarson")).toBe(true);
  });

  it("rejects other scripts", () => {
    expect(isLatinScript("村上春樹")).toBe(false);
    expect(isLatinScript("Харуки Мураками")).toBe(false);
    expect(isLatinScript("هاروكي موراكامي")).toBe(false);
    expect(isLatinScript("Νίκος Καζαντζάκης")).toBe(false);
  });

  it("ignores punctuation, digits and spaces", () => {
    expect(isLatinScript("J. R. R. Tolkien (1892-1973)")).toBe(true);
  });

  it("rejects a mixed name, since half of it is still unreadable", () => {
    expect(isLatinScript("Haruki 村上")).toBe(false);
  });
});

describe("flippingSurnameFirst", () => {
  it("flips the single-comma form", () => {
    expect(flippingSurnameFirst("Murakami, Haruki")).toBe("Haruki Murakami");
  });

  it("leaves a name with no comma alone", () => {
    expect(flippingSurnameFirst("Haruki Murakami")).toBe("Haruki Murakami");
  });

  it("leaves multi-comma shapes alone rather than reordering them wrongly", () => {
    // "Jr., John Smith" would be worse than leaving it be.
    expect(flippingSurnameFirst("Smith, John, Jr.")).toBe("Smith, John, Jr.");
  });

  it("leaves a dangling comma alone", () => {
    expect(flippingSurnameFirst("Murakami,")).toBe("Murakami,");
    expect(flippingSurnameFirst(", Haruki")).toBe(", Haruki");
  });
});

describe("preferredAuthorName", () => {
  it("swaps a non-Latin name for the Latin one", () => {
    expect(preferredAuthorName("村上春樹", "Murakami, Haruki")).toBe("Haruki Murakami");
  });

  it("keeps a Latin name even when a personal_name exists", () => {
    // personal_name is usually a worse, surname-first duplicate.
    expect(preferredAuthorName("Albert Camus", "Camus, Albert")).toBe("Albert Camus");
  });

  it("keeps diacritics rather than reaching for an alternative", () => {
    expect(preferredAuthorName("Patrick Süskind", "Suskind, Patrick")).toBe("Patrick Süskind");
  });

  it("keeps the original when there is no Latin alternative", () => {
    // A name in the wrong script beats no name at all.
    expect(preferredAuthorName("村上春樹", null)).toBe("村上春樹");
    expect(preferredAuthorName("村上春樹", "ムラカミ, ハルキ")).toBe("村上春樹");
  });

  it("falls back to personal_name when there is no name", () => {
    expect(preferredAuthorName(null, "Murakami, Haruki")).toBe("Haruki Murakami");
  });

  it("returns null when the record has neither", () => {
    expect(preferredAuthorName(null, null)).toBeNull();
    expect(preferredAuthorName("", "")).toBeNull();
  });
});
