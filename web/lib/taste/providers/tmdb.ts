/**
 * TMDB → feature record. Expects a movie or TV detail response fetched with
 * `append_to_response=credits,keywords` (see fetchFeatures.ts).
 */

import { yearFrom } from "@/lib/catalog/types";
import type { ExtractedPerson, PersonRole } from "@/lib/taste/people";
import {
  countryCodes,
  languageCode,
  plausibleYear,
  type ExtractedFeatures
} from "@/lib/taste/record";
import type { CatalogTerm } from "@/lib/taste/taxonomy";

interface TMDBPerson {
  id?: number;
  name?: string;
  job?: string;
  order?: number;
}

interface TMDBFeatureResponse {
  release_date?: string;
  first_air_date?: string;
  runtime?: number;
  episode_run_time?: number[];
  number_of_episodes?: number;
  original_language?: string;
  production_countries?: { iso_3166_1?: string }[];
  origin_country?: string[];
  genres?: { id?: number }[];
  keywords?: { keywords?: { name?: string }[]; results?: { name?: string }[] };
  credits?: { cast?: TMDBPerson[]; crew?: TMDBPerson[] };
  created_by?: TMDBPerson[];
}

/**
 * Crew jobs worth a credit, by the role they become. "Novel" and friends
 * are the source author of an adaptation — the cross-media link the spec
 * calls one of the strongest explanations available.
 */
const CREW_ROLES: Record<string, PersonRole> = {
  Director: "director",
  Screenplay: "screenwriter",
  Writer: "screenwriter",
  Novel: "author",
  Book: "author",
  "Short Story": "author",
  "Original Music Composer": "composer",
  Music: "composer"
};

const TOP_CAST = 5;

function person(
  entry: TMDBPerson,
  role: PersonRole,
  billing: number | null
): ExtractedPerson | null {
  if (entry.id === undefined || !entry.name) return null;
  return { name: entry.name, role, billing, ids: { tmdb: String(entry.id) } };
}

/** One credit per (person, role): TMDB lists a writer once per writing job. */
function dedupe(people: ExtractedPerson[]): ExtractedPerson[] {
  const seen = new Set<string>();
  return people.filter((entry) => {
    const key = `${entry.ids.tmdb}|${entry.role}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function peopleOf(detail: TMDBFeatureResponse): ExtractedPerson[] {
  const creators = (detail.created_by ?? []).map((entry) => person(entry, "tv_creator", null));
  const crew = (detail.credits?.crew ?? []).map((entry) => {
    const role = entry.job ? CREW_ROLES[entry.job] : undefined;
    return role ? person(entry, role, null) : null;
  });
  const cast = [...(detail.credits?.cast ?? [])]
    .sort((a, b) => (a.order ?? Number.MAX_SAFE_INTEGER) - (b.order ?? Number.MAX_SAFE_INTEGER))
    .slice(0, TOP_CAST)
    .map((entry, index) => person(entry, "cast", index + 1));
  return dedupe(
    [...creators, ...crew, ...cast].filter((entry): entry is ExtractedPerson => entry !== null)
  );
}

function termsOf(detail: TMDBFeatureResponse): CatalogTerm[] {
  const genres = (detail.genres ?? [])
    .filter((genre) => genre.id !== undefined)
    .map((genre): CatalogTerm => ({ source: "tmdb_genre", key: String(genre.id) }));
  // Movies nest keywords under `keywords`, TV under `results`.
  const keywords = [...(detail.keywords?.keywords ?? []), ...(detail.keywords?.results ?? [])]
    .filter((keyword): keyword is { name: string } => Boolean(keyword.name))
    .map((keyword): CatalogTerm => ({ source: "tmdb_keyword", key: keyword.name }));
  return [...genres, ...keywords];
}

/**
 * Length in minutes. A show's is its whole run — episodes × episode runtime
 * — because commitment is about how much an item asks of you, and a
 * six-season show asks far more than one of its episodes.
 */
function lengthOf(detail: TMDBFeatureResponse, kind: "movie" | "show"): number | null {
  if (kind === "movie") return detail.runtime && detail.runtime > 0 ? detail.runtime : null;
  const episode = detail.episode_run_time?.find((minutes) => minutes > 0);
  const episodes = detail.number_of_episodes;
  return episode && episodes && episodes > 0 ? episode * episodes : null;
}

export function tmdbFeatures(json: unknown, kind: "movie" | "show"): ExtractedFeatures {
  const detail = (json ?? {}) as TMDBFeatureResponse;
  const countries =
    kind === "movie"
      ? (detail.production_countries ?? []).map((country) => country.iso_3166_1)
      : (detail.origin_country ?? []);
  return {
    kind,
    year: plausibleYear(yearFrom(kind === "movie" ? detail.release_date : detail.first_air_date)),
    lengthRaw: lengthOf(detail, kind),
    language: languageCode(detail.original_language),
    countries: countryCodes(countries),
    soundTags: [],
    people: peopleOf(detail),
    terms: termsOf(detail)
  };
}
