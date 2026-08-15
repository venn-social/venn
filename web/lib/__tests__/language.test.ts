import { describe, expect, it } from "vitest";
import { DEFAULT_LANGUAGE, LANGUAGES, labelFor, tmdbLanguage, toLanguage } from "@/lib/language";

/** Mirrors ios/VennTests/Models/AppLanguageTests.swift case for case. */

describe("toLanguage", () => {
  it("accepts a bare code", () => {
    expect(toLanguage("fr")).toBe("fr");
  });

  it("takes the primary subtag from a regional tag", () => {
    // A Québécois phone reports fr-CA; that is still French.
    expect(toLanguage("fr-CA")).toBe("fr");
    expect(toLanguage("pt_BR")).toBe("pt");
  });

  it("is case-insensitive", () => {
    expect(toLanguage("FR")).toBe("fr");
    expect(toLanguage("Ja-JP")).toBe("ja");
  });

  it("falls back rather than throwing on an unsupported language", () => {
    // A bad value in one column must not stop someone using the app.
    expect(toLanguage("cy")).toBe(DEFAULT_LANGUAGE);
    expect(toLanguage("nonsense")).toBe(DEFAULT_LANGUAGE);
  });

  it("falls back on null, undefined and empty", () => {
    expect(toLanguage(null)).toBe(DEFAULT_LANGUAGE);
    expect(toLanguage(undefined)).toBe(DEFAULT_LANGUAGE);
    expect(toLanguage("")).toBe(DEFAULT_LANGUAGE);
  });
});

describe("tmdbLanguage", () => {
  it("returns the region-qualified tag TMDB expects", () => {
    expect(tmdbLanguage("fr")).toBe("fr-FR");
    expect(tmdbLanguage("en")).toBe("en-US");
  });

  it("gives every supported language a tag", () => {
    for (const language of LANGUAGES) {
      expect(tmdbLanguage(language.code)).toMatch(/^[a-z]{2}-[A-Z]{2}$/);
    }
  });
});

describe("labelFor", () => {
  it("names each language in its own language, not in yours", () => {
    // "Deutsch", not "German" — a picker you can read only if you already
    // speak English is not much of a language picker.
    expect(labelFor("de")).toBe("Deutsch");
    expect(labelFor("ja")).toBe("日本語");
  });
});

describe("the supported set", () => {
  it("matches the CHECK constraint on profiles.language", () => {
    // Adding one here without the migration would let the app offer a value
    // the database refuses.
    expect(LANGUAGES.map((language) => language.code)).toEqual([
      "en",
      "fr",
      "es",
      "de",
      "it",
      "pt",
      "ja"
    ]);
  });
});
