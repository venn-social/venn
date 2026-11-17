import type { SupabaseClient } from "@supabase/supabase-js";
import type { MediaCandidate } from "@/lib/catalog/types";
import type { ImportEntry, ImportReport, MatchedEntry, ParsedExport } from "@/lib/import/types";

/** Entries per catalog-match request; bounded so one request stays fast. */
export const MATCH_BATCH = 25;
/** Items per import_library call — the RPC refuses more than 200. */
export const WRITE_BATCH = 200;

/** One element of import_library's `_items` argument. */
export interface ImportItem {
  kind: MediaCandidate["kind"];
  title: string;
  year: number | null;
  primary_creator: string | null;
  cover_url: string | null;
  external_source: MediaCandidate["externalSource"];
  external_id: string;
  action: ImportEntry["action"];
  rating: number | null;
  consumed_at: string | null;
}

export interface ImportDeps {
  /** Catalog matches for a batch of entries, in the same order; null = none. */
  match: (entries: ImportEntry[]) => Promise<(MediaCandidate | null)[]>;
  /** Writes one batch; resolves with how many were new vs. already there. */
  write: (items: ImportItem[]) => Promise<{ imported: number; skipped: number }>;
  /** Called after each step so a screen can show progress. */
  onProgress?: (done: number, total: number) => void;
}

/**
 * Matches every entry against the catalog, then writes the matches.
 *
 * Matching runs to completion before anything is written, so a failure
 * part-way through matching leaves the library untouched. Writing is
 * batched and idempotent on the server, so if a write fails part-way the
 * whole import can simply be run again: what was written is skipped.
 *
 * Mirrors ios/Venn/Features/Import/ImportService.swift.
 */
export async function runImport(parsed: ParsedExport, deps: ImportDeps): Promise<ImportReport> {
  const { matched, unmatched } = await matchAll(parsed.entries, deps);

  let imported = 0;
  let alreadyInLibrary = 0;
  const items = dedupe(matched).map(toImportItem);
  for (let start = 0; start < items.length; start += WRITE_BATCH) {
    const result = await deps.write(items.slice(start, start + WRITE_BATCH));
    imported += result.imported;
    alreadyInLibrary += result.skipped;
  }
  // Two export rows that matched the same catalog item collapse into one
  // write; count the extras as already there, so the totals add up.
  alreadyInLibrary += matched.length - items.length;

  return { imported, alreadyInLibrary, unmatched, problems: parsed.problems };
}

async function matchAll(entries: ImportEntry[], deps: ImportDeps) {
  const matched: MatchedEntry[] = [];
  const unmatched: ImportEntry[] = [];
  for (let start = 0; start < entries.length; start += MATCH_BATCH) {
    const batch = entries.slice(start, start + MATCH_BATCH);
    const results = await deps.match(batch);
    batch.forEach((entry, index) => {
      const candidate = results[index] ?? null;
      if (candidate) matched.push({ entry, candidate });
      else unmatched.push(entry);
    });
    deps.onProgress?.(Math.min(start + MATCH_BATCH, entries.length), entries.length);
  }
  return { matched, unmatched };
}

/**
 * Keeps the most informative entry per catalog item — rated over logged
 * over saved — matching how the server collapses one item to one post.
 */
function dedupe(matched: MatchedEntry[]): MatchedEntry[] {
  const rank = { rated: 0, logged: 1, saved: 2 } as const;
  const byItem = new Map<string, MatchedEntry>();
  for (const item of matched) {
    const existing = byItem.get(item.candidate.id);
    if (!existing || rank[item.entry.action] < rank[existing.entry.action]) {
      byItem.set(item.candidate.id, item);
    }
  }
  return [...byItem.values()];
}

export function toImportItem({ entry, candidate }: MatchedEntry): ImportItem {
  return {
    kind: candidate.kind,
    title: candidate.title,
    year: candidate.year,
    primary_creator: candidate.primaryCreator,
    cover_url: candidate.coverUrl,
    external_source: candidate.externalSource,
    external_id: candidate.externalId,
    action: entry.action,
    rating: entry.rating,
    consumed_at: entry.consumedAt
  };
}

/** The production `write`: one import_library call. */
export async function importLibraryBatch(
  client: SupabaseClient,
  items: ImportItem[]
): Promise<{ imported: number; skipped: number }> {
  const { data, error } = await client.rpc("import_library", { _items: items });
  if (error) throw error;
  const result = data as { imported?: number; skipped?: number } | null;
  return { imported: result?.imported ?? 0, skipped: result?.skipped ?? 0 };
}

/**
 * The production `match`: asks the server route, which holds the TMDB key.
 * Only the fields matching needs leave the browser.
 */
export async function fetchMatches(entries: ImportEntry[]): Promise<(MediaCandidate | null)[]> {
  const response = await fetch("/api/import/match", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      entries: entries.map(({ kind, title, year, creator, isbn }) => ({
        kind,
        title,
        year,
        creator,
        isbn
      }))
    })
  });
  const json = (await response.json()) as { matches?: (MediaCandidate | null)[]; error?: string };
  if (!response.ok || !json.matches) throw new Error(json.error ?? "Matching failed.");
  return json.matches;
}
