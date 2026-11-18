import { csvRecords } from "@/lib/import/csv";
import { parseStars, starsToPost } from "@/lib/import/rating";
import type { ImportEntry, ImportRowProblem, ParsedExport } from "@/lib/import/types";
import { sanitizeSearchQuery } from "@/lib/sanitize";

export const GOODREADS_FILE = "goodreads_library_export.csv";

/**
 * Turns a Goodreads library export into one entry per book.
 *
 * The "Exclusive Shelf" decides what the book is:
 *   - read → logged, rated by "My Rating" (0 means unrated) on the same
 *     star scale as every other import, dated "Date Read" (or "Date Added"
 *     when Goodreads has no read date).
 *   - to-read → saved, dated "Date Added".
 *   - currently-reading → saved: not finished, so not logged, but clearly
 *     something the person means to get through.
 *   - any custom exclusive shelf (e.g. "did-not-finish") → reported, not
 *     imported. Logging a book someone abandoned would be a false record.
 *
 * Goodreads writes ISBNs as spreadsheet formulas (`="0439023483"`) and
 * dates as "YYYY/MM/DD"; both are normalized here.
 *
 * Mirrors ios/Venn/Features/Import/GoodreadsImport.swift.
 */
export function parseGoodreadsExport(text: string): ParsedExport {
  const entries: ImportEntry[] = [];
  const problems: ImportRowProblem[] = [];
  const seen = new Set<string>();

  csvRecords(text).forEach((record, index) => {
    const line = index + 2;
    const problem = (reason: ImportRowProblem["reason"]) =>
      problems.push({ file: GOODREADS_FILE, line, reason });

    const title = sanitizeSearchQuery(record["Title"] ?? "");
    if (!title.valid) return problem("titleTooLong");
    if (!title.value) return problem("missingTitle");

    const shelf = (record["Exclusive Shelf"] ?? "read").trim().toLowerCase();
    if (!["read", "to-read", "currently-reading"].includes(shelf))
      return problem("unsupportedShelf");

    const author = sanitizeSearchQuery(record["Author"] ?? "");
    const creator = author.valid && author.value ? author.value : null;
    const isbn = parseISBN(record["ISBN13"]) ?? parseISBN(record["ISBN"]);

    // Goodreads exports one row per book, but a hand-merged file may not.
    const key = record["Book Id"]?.trim() || `${title.value}|${creator ?? ""}`;
    if (seen.has(key)) return;
    seen.add(key);

    const year =
      parseYear(record["Original Publication Year"]) ?? parseYear(record["Year Published"]);
    const added = parseDate(record["Date Added"]);
    const base = { kind: "book" as const, title: title.value, year, creator, isbn };

    if (shelf === "read") {
      const { action, rating } = starsToPost(parseStars(record["My Rating"]));
      entries.push({
        ...base,
        action,
        rating,
        consumedAt: parseDate(record["Date Read"]) ?? added
      });
    } else {
      entries.push({ ...base, action: "saved", rating: null, consumedAt: added });
    }
  });

  return { entries, problems };
}

/** `="9780439023481"`, `9780439023481` or `=""` → the digits, or null. */
export function parseISBN(cell: string | undefined): string | null {
  const value = (cell ?? "").replace(/[="\s-]/g, "").toUpperCase();
  return /^(\d{13}|\d{9}[\dX])$/.test(value) ? value : null;
}

/** "2023/01/15" → "2023-01-15"; anything else → null. */
export function parseDate(cell: string | undefined): string | null {
  const match = /^(\d{4})\/(\d{2})\/(\d{2})$/.exec((cell ?? "").trim());
  return match ? `${match[1]}-${match[2]}-${match[3]}` : null;
}

function parseYear(cell: string | undefined): number | null {
  const value = Number.parseInt((cell ?? "").trim(), 10);
  return Number.isInteger(value) && value >= 1800 && value <= 2200 ? value : null;
}
