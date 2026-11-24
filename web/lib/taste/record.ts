/**
 * The normalised feature record every provider mapper produces, and the
 * rows it becomes. Spec §1; tables in 20261124090000_taste_engine_schema.sql.
 */

import type { MediaKind } from "@/lib/media";
import type { ExtractedPerson } from "@/lib/taste/people";
import type { CatalogTerm } from "@/lib/taste/taxonomy";

/** Bump when a mapper changes what it would write, so the script re-extracts. */
export const EXTRACTOR_VERSION = 1;

export const SOUND_VOCABULARY = [
  "guitar",
  "synth",
  "strings",
  "piano",
  "brass",
  "voice-led",
  "energy_low",
  "energy_high"
] as const;
export type SoundTag = (typeof SOUND_VOCABULARY)[number];

/** What a provider mapper knows about one item. Null means the catalog did not say. */
export interface ExtractedFeatures {
  kind: MediaKind;
  year: number | null;
  /** Minutes for films, shows (all episodes) and albums; pages for books. */
  lengthRaw: number | null;
  language: string | null;
  countries: string[];
  soundTags: SoundTag[];
  people: ExtractedPerson[];
  terms: CatalogTerm[];
}

/** A `media_features` row. */
export interface MediaFeaturesRow {
  media_id: string;
  year: number | null;
  decade: number | null;
  length_raw: number | null;
  commitment: number | null;
  language: string | null;
  countries: string[];
  sound_tags: SoundTag[];
  extractor_version: number;
}

export function decadeOf(year: number | null): number | null {
  return year === null ? null : year - (year % 10);
}

/** A plausible year or null — catalogs carry "0001" and "9999" placeholders. */
export function plausibleYear(year: number | null | undefined): number | null {
  return typeof year === "number" && Number.isInteger(year) && year >= 1800 && year <= 2200
    ? year
    : null;
}

/** "en" stays, "xx" (TMDB's "no language") and junk become null. */
export function languageCode(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const code = value.toLowerCase();
  return /^[a-z]{2}$/.test(code) && code !== "xx" ? code : null;
}

/** ISO 3166-1 alpha-2, upper-case, deduplicated, at most 20. */
export function countryCodes(values: unknown[]): string[] {
  const codes = values
    .filter((value): value is string => typeof value === "string")
    .map((value) => value.toUpperCase())
    // "XW" is MusicBrainz's "worldwide" and "XE" its "Europe": not countries.
    .filter((value) => /^[A-Z]{2}$/.test(value) && !value.startsWith("X"));
  return [...new Set(codes)].slice(0, 20);
}

/**
 * Every rule the database enforces on a `media_features` row, checked before
 * writing so a bad record is reported by name instead of failing a batch.
 */
export function featureRowProblems(row: MediaFeaturesRow): string[] {
  const problems: string[] = [];
  if (row.year !== null && (row.year < 1800 || row.year > 2200)) problems.push("year out of range");
  if (row.decade !== null && row.decade !== decadeOf(row.year))
    problems.push("decade disagrees with year");
  if (row.length_raw !== null && !(row.length_raw > 0)) problems.push("length must be positive");
  if (row.commitment !== null && (row.commitment < 0 || row.commitment > 1)) {
    problems.push("commitment out of [0, 1]");
  }
  if (row.language !== null && !/^[a-z]{2}$/.test(row.language)) problems.push("bad language code");
  if (row.countries.length > 20 || row.countries.some((code) => !/^[A-Z]{2}$/.test(code))) {
    problems.push("bad country codes");
  }
  if (row.sound_tags.some((tag) => !(SOUND_VOCABULARY as readonly string[]).includes(tag))) {
    problems.push("sound tag outside the vocabulary");
  }
  return problems;
}
