import type { MediaCandidate } from "@/lib/catalog/types";
import { bestBookMatch, bestMatch, withoutSeries } from "@/lib/import/match";
import type { ImportEntry } from "@/lib/import/types";

/** Entries the match route accepts per request. */
export const MAX_MATCH_REQUEST = 25;

/**
 * Catalog lookups in flight at once. TMDB allows dozens a second; Open
 * Library throttles hard and answers a burst with an empty 200, which
 * would read as "no match", so books go two at a time.
 */
const CONCURRENCY: Record<ImportEntry["kind"], number> = { movie: 5, show: 5, book: 2, album: 2 };

export type MatchableEntry = Pick<ImportEntry, "kind" | "title" | "year" | "creator" | "isbn">;

export interface CatalogLookup {
  search: (kind: ImportEntry["kind"], query: string) => Promise<MediaCandidate[]>;
}

/**
 * Server side of matching: catalog searches per entry, then the matcher for
 * its kind. A failed search for one entry counts as unmatched rather than
 * failing the batch — one odd title should not sink a 500-film import.
 */
export async function matchEntries(
  entries: MatchableEntry[],
  lookup: CatalogLookup
): Promise<(MediaCandidate | null)[]> {
  const results: (MediaCandidate | null)[] = new Array(entries.length).fill(null);
  const concurrency = Math.min(...entries.map((entry) => CONCURRENCY[entry.kind]), 5);
  let next = 0;

  async function worker() {
    while (next < entries.length) {
      const index = next;
      next += 1;
      try {
        results[index] = await matchOne(entries[index], lookup);
      } catch {
        results[index] = null;
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(concurrency, entries.length) }, worker));
  return results;
}

/**
 * Books try the ISBN first: an ISBN hit is the book, whatever its title
 * says in that edition. Without one — or when Open Library does not know
 * it — they fall back to title and author.
 */
export async function matchOne(
  entry: MatchableEntry,
  lookup: CatalogLookup
): Promise<MediaCandidate | null> {
  if (entry.kind !== "book") {
    return bestMatch(entry.title, entry.year, await lookup.search(entry.kind, entry.title));
  }
  if (entry.isbn) {
    const [hit] = await lookup.search("book", `isbn:${entry.isbn}`);
    if (hit) return hit;
  }
  // The series suffix is Goodreads' own and only adds noise to the search.
  const title = withoutSeries(entry.title);
  const query = entry.creator ? `${title} ${entry.creator}` : title;
  return bestBookMatch(entry.title, entry.creator, await lookup.search("book", query));
}
