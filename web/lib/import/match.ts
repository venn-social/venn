import type { MediaCandidate } from "@/lib/catalog/types";

/**
 * Title comparison key: case, accents, punctuation, "&" vs "and" and a
 * leading article all differ between catalogs for the same work ("The
 * Grand Budapest Hotel" vs "Grand Budapest Hotel", "Amélie" vs "Amelie").
 * Mirrors ImportMatcher.normalizedTitle on iOS.
 */
export function normalizeTitle(title: string): string {
  return title
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .replace(/^(the|a|an) /, "")
    .replace(/\s+/g, " ");
}

/**
 * Picks the catalog result an export row refers to, or null when none is a
 * safe match. Results arrive in the catalog's relevance order, which breaks
 * ties.
 *
 * In order of confidence:
 *   1. Same title, same year.
 *   2. Same title, year off by one — exports and catalogs disagree about
 *      festival vs. release years.
 *   3. Same title, and the row has no year to check.
 *   4. Same year, and one title contains the other ("Dune" vs "Dune: Part
 *      One") — only when the row has a year to anchor it.
 *
 * A row whose title matches nothing is reported unmatched rather than
 * guessed: a wrong title in someone's library is worse than a gap.
 */
export function bestMatch(
  title: string,
  year: number | null,
  candidates: MediaCandidate[]
): MediaCandidate | null {
  const key = normalizeTitle(title);
  if (!key) return null;
  const sameTitle = candidates.filter((c) => normalizeTitle(c.title) === key);

  if (year !== null) {
    const exact = sameTitle.find((c) => c.year === year);
    if (exact) return exact;
    const near = sameTitle.find((c) => c.year !== null && Math.abs(c.year - year) <= 1);
    if (near) return near;
    return (
      candidates.find((c) => {
        if (c.year !== year) return false;
        const other = normalizeTitle(c.title);
        return other.length > 0 && (other.includes(key) || key.includes(other));
      }) ?? null
    );
  }

  return sameTitle[0] ?? null;
}
