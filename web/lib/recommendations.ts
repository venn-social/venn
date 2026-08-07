import { candidateId, type ExternalSource, type MediaCandidate } from "@/lib/catalog/types";
import { toMedia, type Media, type MediaKind, type MediaRow } from "@/lib/media";

/** Which tier a shelf came from. Ordered by how much venn knows about you. */
export type ShelfSource = "taste_twins" | "followed" | "similar" | "trending";

/** Tier order is fixed — see the spec's ladder. */
const TIER_ORDER: ShelfSource[] = ["taste_twins", "followed", "similar", "trending"];

/** A shelf below this reads as broken rather than as a recommendation. */
export const MIN_SHELF_ITEMS = 3;
/** More than this and Explorer becomes a wall of rows. */
export const MAX_SHELVES = 4;
export const MAX_SHELF_ITEMS = 12;

export interface ExcludedKey {
  source: ExternalSource;
  kind: MediaKind;
  id: string;
}

export interface Seed {
  media_id: string;
  title: string;
  kind: MediaKind;
  external_source: ExternalSource;
  external_id: string;
  rating: number;
}

export interface FeedSection {
  source: "taste_twins" | "followed";
  items: MediaRow[];
}

/** Exactly what `recommendation_feed()` returns. */
export interface RecommendationFeed {
  sections: FeedSection[];
  seeds: Seed[];
  excluded: ExcludedKey[];
}

/** A shelf's worth of catalog results, before filtering. */
export interface CandidateShelf {
  source: "similar" | "trending";
  /** The title this shelf is "more like". Null for trending. */
  seedTitle: string | null;
  candidates: MediaCandidate[];
}

/**
 * An item on a shelf. Rows from venn's own catalog are `Media` and can be
 * opened directly; catalog results are `MediaCandidate` and have to be
 * upserted before they can be. The UI treats them differently, so the
 * distinction is in the type rather than discovered at render time.
 */
export type ShelfItem =
  | { kind: "media"; media: Media }
  | { kind: "candidate"; candidate: MediaCandidate };

export interface Shelf {
  source: ShelfSource;
  seedTitle: string | null;
  items: ShelfItem[];
}

/**
 * Turn the RPC payload and whatever the catalogs returned into the shelves
 * to render.
 *
 * Pure by design: no network, no clock, no UI. This is the only logic that
 * exists on both platforms, so it is kept small enough to hold in your head
 * and tested with the same cases on each side. Its Swift twin is
 * ios/Venn/Features/Explorer/Recommendations/RecommendationAssembler.swift.
 */
export function assembleShelves(
  feed: RecommendationFeed,
  candidateShelves: CandidateShelf[]
): Shelf[] {
  const excluded = new Set(
    feed.excluded.map((key) => candidateId(key.source, key.kind, key.id))
  );
  // Grows as shelves are built, so an item claimed by a higher tier cannot
  // reappear lower down.
  const claimed = new Set<string>();

  const fromSections: Shelf[] = feed.sections.map((section) => ({
    source: section.source,
    seedTitle: null,
    // toMedia returns null for a kind this client doesn't know, so that a
    // media kind shipped server-side ahead of a release makes individual
    // items disappear rather than breaking the shelf. Honour that.
    items: section.items
      .map(toMedia)
      .filter((media): media is Media => media !== null)
      .map((media) => ({ kind: "media" as const, media }))
  }));

  const fromCandidates: Shelf[] = candidateShelves.map((shelf) => ({
    source: shelf.source,
    seedTitle: shelf.seedTitle,
    items: shelf.candidates.map((candidate) => ({
      kind: "candidate" as const,
      candidate
    }))
  }));

  const ordered = [...fromSections, ...fromCandidates].sort(
    (a, b) => TIER_ORDER.indexOf(a.source) - TIER_ORDER.indexOf(b.source)
  );

  const shelves: Shelf[] = [];
  for (const shelf of ordered) {
    if (shelves.length >= MAX_SHELVES) break;

    const items: ShelfItem[] = [];
    for (const item of shelf.items) {
      if (items.length >= MAX_SHELF_ITEMS) break;

      const key = itemKey(item);
      if (key === null) {
        // A hand-typed row has no catalog identity, so it can be neither
        // excluded nor deduped. Show it — it came from venn's own data.
        items.push(item);
        continue;
      }
      if (excluded.has(key) || claimed.has(key)) continue;

      claimed.add(key);
      items.push(item);
    }

    if (items.length >= MIN_SHELF_ITEMS) {
      shelves.push({ source: shelf.source, seedTitle: shelf.seedTitle, items });
    }
  }

  return shelves;
}

/** `"<source>:<kind>:<externalId>"`, or null when the item has no catalog identity. */
function itemKey(item: ShelfItem): string | null {
  if (item.kind === "candidate") return item.candidate.id;

  const { externalSource, externalId, kind } = item.media;
  if (!externalSource || !externalId) return null;
  return candidateId(externalSource, kind, externalId);
}
