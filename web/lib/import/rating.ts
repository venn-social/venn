import { ratingToPost, type RatingChoice } from "@/lib/compose";
import type { PostAction } from "@/lib/feed";

/**
 * How a star rating from another app becomes a venn sentiment.
 *
 * One scale for every import, so a Letterboxd 4.5 and a Goodreads 5 mean
 * the same thing in your library:
 *
 *   4.5–5 stars  → Love
 *   3.5–4 stars  → Like
 *   2.5–3 stars  → no sentiment (logged, unrated)
 *   0.5–2 stars  → Dislike
 *
 * The middle band is deliberately neutral: "it was fine" is neither a like
 * nor a dislike, and guessing either would put a false opinion on a
 * profile. Mirrors ios/Venn/Features/Import/ImportRating.swift.
 */
export function starsToChoice(stars: number | null): RatingChoice | null {
  if (stars === null || !Number.isFinite(stars) || stars <= 0) return null;
  if (stars >= 4.5) return "love";
  if (stars >= 3.5) return "like";
  if (stars >= 2.5) return null;
  return "dislike";
}

export function starsToPost(stars: number | null): { action: PostAction; rating: number | null } {
  return ratingToPost(starsToChoice(stars));
}

/**
 * Reads a star rating cell. Empty, zero ("not rated" on Goodreads) and
 * anything outside 0.5–5 come back as null rather than as a rating.
 */
export function parseStars(cell: string | undefined): number | null {
  if (!cell) return null;
  const value = Number.parseFloat(cell.trim());
  if (!Number.isFinite(value) || value < 0.5 || value > 5) return null;
  return value;
}
