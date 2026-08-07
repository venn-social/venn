import type { Shelf } from "@/lib/recommendations";

/**
 * Shelf headings.
 *
 * Copy lives here rather than in SQL so that rule 17's parity check stays
 * in the clients, where it already is — the RPC returns a `source`
 * discriminator and nothing user-facing.
 *
 * Every label states what the shelf actually is. "Trending this week" is
 * not dressed up as a personal recommendation, and a books shelf built
 * from the same author says so rather than implying a taste match venn
 * cannot support.
 *
 * Mirrored by iOS's `RecommendationShelf.title` — keep them identical.
 */
export function shelfTitle(shelf: Shelf): string {
  switch (shelf.source) {
    case "taste_twins":
      return "Popular with people who match your taste";
    case "followed":
      return "Loved by people you follow";
    case "similar":
      return shelf.seedTitle ? `More like ${shelf.seedTitle}` : "More like what you loved";
    case "trending":
      return "Trending this week";
  }
}
