/**
 * Open Library → feature record. Expects one doc from `search.json`, which
 * carries everything this needs in a single request (see fetchFeatures.ts):
 * `first_publish_year`, `number_of_pages_median`, `language`, `subject`,
 * `author_key`, `author_name`.
 */

import type { ExtractedPerson } from "@/lib/taste/people";
import { languageFromThreeLetter } from "@/lib/taste/providers/languages";
import { plausibleYear, type ExtractedFeatures } from "@/lib/taste/record";
import type { CatalogTerm } from "@/lib/taste/taxonomy";

interface OLSearchDoc {
  first_publish_year?: number;
  number_of_pages_median?: number;
  language?: string[];
  subject?: string[];
  author_key?: string[];
  author_name?: string[];
}

/**
 * Subjects Open Library uses for shelving rather than describing — places,
 * people, awards, reading-list chatter. They never map to a node anyway,
 * but dropping them early keeps the dry-run report readable.
 */
const NOISE =
  /^(nyt:|award:|place:|person:|time:|accessible book|protected daisy|in library|reading level)/i;

/** Subjects capped at 60: popular works carry hundreds, most of them noise. */
const MAX_SUBJECTS = 60;

function peopleOf(doc: OLSearchDoc): ExtractedPerson[] {
  const keys = doc.author_key ?? [];
  const names = doc.author_name ?? [];
  return keys
    .map((key, index): ExtractedPerson | null => {
      const name = names[index];
      if (!name || !/^OL[0-9]+A$/.test(key)) return null;
      return { name, role: "author", billing: null, ids: { openlibrary: key } };
    })
    .filter((entry): entry is ExtractedPerson => entry !== null);
}

function termsOf(doc: OLSearchDoc): CatalogTerm[] {
  return (doc.subject ?? [])
    .filter((subject) => !NOISE.test(subject))
    .slice(0, MAX_SUBJECTS)
    .map((subject) => ({ source: "openlibrary_subject", key: subject }));
}

/**
 * The work's language, only when the catalog is unambiguous. Open Library
 * lists every edition's language with no order of precedence, so a novel
 * translated into twelve languages has no knowable "original" here.
 */
function languageOf(doc: OLSearchDoc): string | null {
  const languages = doc.language ?? [];
  return languages.length === 1 ? languageFromThreeLetter(languages[0]) : null;
}

export function openLibraryFeatures(json: unknown): ExtractedFeatures {
  const doc = (json ?? {}) as OLSearchDoc;
  const pages = doc.number_of_pages_median;
  return {
    kind: "book",
    year: plausibleYear(doc.first_publish_year),
    lengthRaw: typeof pages === "number" && pages > 0 ? pages : null,
    language: languageOf(doc),
    // Open Library records publishers' places, not a work's origin.
    countries: [],
    soundTags: [],
    people: peopleOf(doc),
    terms: termsOf(doc)
  };
}
