import type { MediaKind } from "@/lib/media";
import type { PostAction } from "@/lib/feed";
import type { MediaCandidate } from "@/lib/catalog/types";

/** One title from an export, merged across its files, ready to match. */
export interface ImportEntry {
  kind: MediaKind;
  /** Sanitized; used as the catalog search query, never stored. */
  title: string;
  year: number | null;
  /** Author for books — narrows the match. */
  creator: string | null;
  /** ISBN-13 or ISBN-10 when the export has one — the strongest match key. */
  isbn: string | null;
  action: PostAction;
  rating: number | null;
  /** "YYYY-MM-DD" from the export; the imported post is dated to it. */
  consumedAt: string | null;
}

/** A row that could not be turned into an entry at all. */
export interface ImportRowProblem {
  file: string;
  /** 1-based line in the file, counting the header as line 1. */
  line: number;
  /**
   * unsupportedShelf: a Goodreads exclusive shelf other than read, to-read or
   * currently-reading (e.g. "did-not-finish"), whose meaning venn cannot
   * represent without guessing.
   */
  reason: "missingTitle" | "titleTooLong" | "unsupportedShelf";
}

export interface ParsedExport {
  entries: ImportEntry[];
  problems: ImportRowProblem[];
}

/** An entry plus the catalog item it matched. */
export interface MatchedEntry {
  entry: ImportEntry;
  candidate: MediaCandidate;
}

/** What an import did, for the screen that will eventually show it. */
export interface ImportReport {
  imported: number;
  /** Already in the person's venn library; left untouched. */
  alreadyInLibrary: number;
  /** Nothing in the catalog matched these. */
  unmatched: ImportEntry[];
  problems: ImportRowProblem[];
}
