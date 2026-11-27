/**
 * People across catalogs (§1.2). One row per real person, never merged by
 * name: two different "John Williams" live in exactly these catalogs.
 */

export type PersonRole =
  | "director"
  | "author"
  | "primary_artist"
  | "tv_creator"
  | "composer"
  | "screenwriter"
  | "producer"
  | "cast"
  | "translator";

export interface PersonIds {
  wikidata?: string;
  tmdb?: string;
  openlibrary?: string;
  musicbrainz?: string;
}

/** A credit as extracted from one catalog record. */
export interface ExtractedPerson {
  name: string;
  role: PersonRole;
  /** 1-based cast order; null for every other role. */
  billing: number | null;
  ids: PersonIds;
}

/** A `people` row as the script sees it. */
export interface PersonRow {
  id: string;
  wikidata_qid: string | null;
  tmdb_id: string | null;
  openlibrary_id: string | null;
  musicbrainz_id: string | null;
  display_name: string;
}

const ID_COLUMNS = [
  ["wikidata", "wikidata_qid"],
  ["tmdb", "tmdb_id"],
  ["openlibrary", "openlibrary_id"],
  ["musicbrainz", "musicbrainz_id"]
] as const;

export type PersonPlan =
  | { action: "insert"; row: Omit<PersonRow, "id"> }
  | { action: "update"; id: string; patch: Partial<Omit<PersonRow, "id">> }
  | { action: "keep"; id: string };

/** "https://www.wikidata.org/wiki/Q42" or "Q42" → "Q42"; anything else → undefined. */
export function wikidataQid(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const match = value.match(/(?:^|\/)(Q[1-9][0-9]*)$/);
  return match?.[1];
}

/**
 * Decide how one extracted person lands in `people`, given the rows that
 * already share any of its ids.
 *
 * Trust order is the spec's: a Wikidata QID first, then a per-catalog id. A
 * QID match wins even if a different row holds the catalog id — that row is
 * left alone rather than merged, because two rows disagreeing about who a
 * person is is a question for a human, not for a script. A missing id is
 * filled in, never overwritten.
 */
export function planPerson(person: ExtractedPerson, existing: PersonRow[]): PersonPlan {
  const byQid = person.ids.wikidata
    ? existing.find((row) => row.wikidata_qid === person.ids.wikidata)
    : undefined;
  const byCatalog = ID_COLUMNS.slice(1)
    .map(([key, column]) => {
      const value = person.ids[key];
      return value ? existing.find((row) => row[column] === value) : undefined;
    })
    .find((row) => row !== undefined);

  // A catalog-id match that already carries a *different* QID is somebody
  // else; never attach this person to it.
  const catalogMatch =
    byCatalog &&
    (!person.ids.wikidata ||
      !byCatalog.wikidata_qid ||
      byCatalog.wikidata_qid === person.ids.wikidata)
      ? byCatalog
      : undefined;
  const target = byQid ?? catalogMatch;

  if (!target) {
    return {
      action: "insert",
      row: {
        wikidata_qid: person.ids.wikidata ?? null,
        tmdb_id: person.ids.tmdb ?? null,
        openlibrary_id: person.ids.openlibrary ?? null,
        musicbrainz_id: person.ids.musicbrainz ?? null,
        display_name: person.name.slice(0, 200)
      }
    };
  }

  const patch: Partial<Omit<PersonRow, "id">> = {};
  for (const [key, column] of ID_COLUMNS) {
    const value = person.ids[key];
    // Only fill a gap, and only with an id no other row already claims —
    // the column is unique, and the other row is the authority on it.
    if (value && target[column] === null && !existing.some((row) => row[column] === value)) {
      patch[column] = value;
    }
  }
  return Object.keys(patch).length > 0
    ? { action: "update", id: target.id, patch }
    : { action: "keep", id: target.id };
}

/** Does this person carry at least one id the `people` table will accept? */
export function hasIdentity(person: ExtractedPerson): boolean {
  return Boolean(
    person.ids.wikidata || person.ids.tmdb || person.ids.openlibrary || person.ids.musicbrainz
  );
}
