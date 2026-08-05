import type { MediaKind } from "@/lib/media";

/** Mirrors ios/Venn/Models/Media.swift's ExternalSource. */
export type ExternalSource = "tmdb" | "openlibrary" | "musicbrainz";

/**
 * A search result from an external catalog, before it is persisted to
 * public.media. Mirrors ios/Venn/Models/MediaCandidate.swift.
 */
export interface MediaCandidate {
  /** "<source>:<kind>:<externalId>" — stable and unique across providers. */
  id: string;
  title: string;
  primaryCreator: string | null;
  year: number | null;
  coverUrl: string | null;
  /** Plot/description. Null for music — MusicBrainz doesn't surface one. */
  overview: string | null;
  externalId: string;
  externalSource: ExternalSource;
  kind: MediaKind;
}

/**
 * Kind is part of the key, not just source and id: TMDB numbers movies and
 * TV independently, so movie 123 and show 123 are different things that
 * would otherwise collide — visibly so in the "All" category, which
 * searches both at once.
 */
export function candidateId(
  source: ExternalSource,
  kind: MediaKind,
  externalId: string
): string {
  return `${source}:${kind}:${externalId}`;
}

/**
 * Pulls a year out of the assorted date shapes these APIs return
 * ("2023-06-02", "2016-05", "1999"). Ports ExternalAPI.year(from:).
 */
export function yearFrom(dateString: string | null | undefined): number | null {
  if (!dateString || dateString.length < 4) return null;
  const year = Number.parseInt(dateString.slice(0, 4), 10);
  return Number.isNaN(year) ? null : year;
}
