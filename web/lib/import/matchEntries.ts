import type { MediaCandidate } from "@/lib/catalog/types";
import { bestMatch } from "@/lib/import/match";
import type { ImportEntry } from "@/lib/import/types";

/** Entries the match route accepts per request. */
export const MAX_MATCH_REQUEST = 25;
/** Catalog lookups in flight at once — polite to TMDB's per-second limit. */
const CONCURRENCY = 5;

export type MatchableEntry = Pick<ImportEntry, "kind" | "title" | "year" | "creator" | "isbn">;

export interface CatalogLookup {
  search: (kind: ImportEntry["kind"], query: string) => Promise<MediaCandidate[]>;
}

/**
 * Server side of matching: one catalog search per entry, then bestMatch.
 * A failed search for one entry counts as unmatched rather than failing
 * the batch — one odd title should not sink a 500-film import.
 */
export async function matchEntries(
  entries: MatchableEntry[],
  lookup: CatalogLookup
): Promise<(MediaCandidate | null)[]> {
  const results: (MediaCandidate | null)[] = new Array(entries.length).fill(null);
  let next = 0;

  async function worker() {
    while (next < entries.length) {
      const index = next;
      next += 1;
      const entry = entries[index];
      try {
        const candidates = await lookup.search(entry.kind, entry.title);
        results[index] = bestMatch(entry.title, entry.year, candidates);
      } catch {
        results[index] = null;
      }
    }
  }

  await Promise.all(Array.from({ length: Math.min(CONCURRENCY, entries.length) }, worker));
  return results;
}
