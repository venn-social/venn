/**
 * The language someone reads in.
 *
 * Drives what the catalog is asked for — a French reader searching "the
 * stranger" should find L'étranger's French edition, not whatever language
 * the work was written in.
 *
 * It deliberately does not localise stored `media` rows. That table is one
 * shared row per item, referenced by everyone's posts, so a title there
 * belongs to every reader at once and cannot be two languages at the same
 * time. This changes what each person *finds*, not what everyone *sees*.
 *
 * The list is short on purpose: each entry is a promise that search actually
 * behaves differently, and offering a language the providers cannot serve is
 * worse than not offering it. TMDB localises properly, Open Library only
 * through editions, MusicBrainz not at all.
 *
 * Mirrors ios/Venn/Models/AppLanguage.swift.
 */

export const LANGUAGES = [
  { code: "en", label: "English", tmdb: "en-US" },
  { code: "fr", label: "Français", tmdb: "fr-FR" },
  { code: "es", label: "Español", tmdb: "es-ES" },
  { code: "de", label: "Deutsch", tmdb: "de-DE" },
  { code: "it", label: "Italiano", tmdb: "it-IT" },
  { code: "pt", label: "Português", tmdb: "pt-PT" },
  { code: "ja", label: "日本語", tmdb: "ja-JP" }
] as const;

export type LanguageCode = (typeof LANGUAGES)[number]["code"];

export const DEFAULT_LANGUAGE: LanguageCode = "en";

/** Every language shown in its own name, never translated into yours. */
export function labelFor(code: LanguageCode): string {
  return LANGUAGES.find((language) => language.code === code)?.label ?? code;
}

/** The region-qualified tag TMDB wants. */
export function tmdbLanguage(code: LanguageCode): string {
  return LANGUAGES.find((language) => language.code === code)?.tmdb ?? "en-US";
}

/**
 * Narrow anything to a supported language.
 *
 * Used for both the stored column and a browser's `navigator.language`, so
 * "fr-CA", "FR" and "fr" all land on French, and anything unsupported falls
 * back rather than throwing — a bad value in one column should not stop
 * someone using the app.
 */
export function toLanguage(value: string | null | undefined): LanguageCode {
  if (!value) return DEFAULT_LANGUAGE;
  const primary = value.toLowerCase().split(/[-_]/)[0];
  const match = LANGUAGES.find((language) => language.code === primary);
  return match ? match.code : DEFAULT_LANGUAGE;
}
