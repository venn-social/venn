/**
 * The media catalog's shared shape. Lives on its own because both the feed
 * and the profile shelves decode the same embedded `media` row — on iOS
 * those two decoders are near-duplicates and are tracked as tech-debt row
 * 3 ("if a third copy appears, extract a shared row DTO"). Web extracts it
 * up front instead.
 *
 * Mirrors `public.media` and ios/Venn/Models/Media.swift.
 */
export type MediaKind = "movie" | "show" | "book" | "album";

/** Mirrors ios/Venn/Models/Media.swift's ExternalSource. */
export type ExternalSource = "tmdb" | "openlibrary" | "musicbrainz";

const EXTERNAL_SOURCES: readonly string[] = ["tmdb", "openlibrary", "musicbrainz"];

function isExternalSource(value: unknown): value is ExternalSource {
  return typeof value === "string" && EXTERNAL_SOURCES.includes(value);
}

export const MEDIA_KINDS: readonly string[] = ["movie", "show", "book", "album"];

export interface Media {
  id: string;
  kind: MediaKind;
  title: string;
  year: number | null;
  primaryCreator: string | null;
  coverUrl: string | null;
  /**
   * Which catalog this came from, and its id there. Null for rows a user
   * typed by hand. Together they're what lets the detail page fetch
   * description, cast, and availability from the right provider.
   */
  externalSource: ExternalSource | null;
  externalId: string | null;
}

export interface MediaRow {
  id: string;
  kind: MediaKind;
  title: string;
  year: number | null;
  primary_creator: string | null;
  cover_url: string | null;
  external_source?: string | null;
  external_id?: string | null;
}

/**
 * Lifts a wire row into the domain shape. Returns null for a `kind` this
 * client doesn't know, so a new media kind shipped server-side ahead of a
 * client release makes individual items disappear rather than breaking the
 * whole surface. Mirrors iOS's failable `Media.init(row:)`.
 */
export function toMedia(row: MediaRow | null | undefined): Media | null {
  if (!row || !MEDIA_KINDS.includes(row.kind)) return null;

  return {
    id: row.id,
    kind: row.kind,
    title: row.title,
    year: row.year,
    primaryCreator: row.primary_creator,
    coverUrl: row.cover_url,
    externalSource: isExternalSource(row.external_source) ? row.external_source : null,
    externalId: row.external_id ?? null,
  };
}

/** "2023 · Celine Song" — whichever of year / creator is present. */
export function mediaMetadata(media: Media): string {
  return [media.year?.toString(), media.primaryCreator]
    .filter((part): part is string => Boolean(part))
    .join(" · ");
}
