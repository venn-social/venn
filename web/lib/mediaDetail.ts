import type { SupabaseClient } from "@supabase/supabase-js";
import { readOrListenLinks, withProviderUrls } from "@/lib/catalog/destinations";
import { EMPTY_DETAIL, sourceUrlFor, type MediaDetail, type WatchLink } from "@/lib/catalog/detail";
import { fetchMusicBrainzDetail } from "@/lib/catalog/musicBrainz";
import { fetchOpenLibraryDetail } from "@/lib/catalog/openLibrary";
import { fetchTMDBDetail } from "@/lib/catalog/tmdb";
import { toMedia, type Media, type MediaKind, type MediaRow } from "@/lib/media";

/** One catalog row by id. Null when it doesn't exist — the page 404s. */
export async function fetchMediaById(
  client: SupabaseClient,
  mediaId: string
): Promise<Media | null> {
  const { data, error } = await client.from("media").select("*").eq("id", mediaId).maybeSingle();

  if (error) {
    if (error.code === "22P02") return null; // junk uuid in the URL
    throw error;
  }
  return data ? toMedia(data as MediaRow) : null;
}

/**
 * Enriched detail from whichever catalog this row came from.
 *
 * Called **directly** from the Server Component rather than over HTTP to
 * our own API. An earlier version derived the outbound origin from the
 * request's Host header and forwarded the user's cookie to it — a spoofed
 * Host would then have shipped the session to an attacker. Calling the
 * provider functions in-process removes the hop, the header trust, and the
 * cookie forwarding all at once, and is faster besides. The TMDB key stays
 * server-only either way, because this only ever runs on the server.
 *
 * Returns the empty shape rather than throwing when the row has no
 * external source (someone typed it by hand) or the provider is down: the
 * page still has title, cover, year, and creator from our own row, and a
 * thin detail section beats a broken page.
 */
export async function loadMediaDetail(media: Media, region: string): Promise<MediaDetail> {
  if (!media.externalSource || !media.externalId) return EMPTY_DETAIL;

  const sourceUrl = sourceUrlFor(media.externalSource, media.kind, media.externalId);

  try {
    const detail = await fetchFromProvider(media, region);
    return { ...detail, sourceUrl, ...destinations(media, detail.watchLinks, region) };
  } catch {
    // Still give them the link out, even if we couldn't enrich — and say
    // that we failed rather than implying the item simply has no detail.
    return { ...EMPTY_DETAIL, sourceUrl, unavailable: true, ...destinations(media, [], region) };
  }
}

/**
 * Where to actually watch, read, or listen to this.
 *
 * Screen availability comes from TMDB and is only re-pointed at the
 * providers themselves. Books and albums have no availability data at any
 * of our catalogs, so their links are built from the title and creator —
 * which is why they survive the provider being down, and why they're
 * applied on the failure path too.
 */
function destinations(
  media: Media,
  links: WatchLink[],
  region: string
): Pick<MediaDetail, "watchLinks" | "watchRegion"> {
  if (media.kind === "book" || media.kind === "album") {
    return {
      watchLinks: readOrListenLinks(media.kind, media.title, media.primaryCreator, region),
      watchRegion: region
    };
  }
  return { watchLinks: withProviderUrls(links, media.title, region), watchRegion: region };
}

function fetchFromProvider(media: Media, region: string): Promise<MediaDetail> {
  if (media.externalSource === "openlibrary") {
    return fetchOpenLibraryDetail(media.externalId!);
  }
  if (media.externalSource === "musicbrainz") {
    return fetchMusicBrainzDetail(media.externalId!);
  }

  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey) throw new Error("Movie and show details need a TMDB API key.");
  return fetchTMDBDetail(
    media.kind === "movie" ? "movie" : "show",
    media.externalId!,
    apiKey,
    region
  );
}

/** "2h 17m" from a minute count. Null passes through so callers can skip it. */
export function formatRuntime(minutes: number | null): string | null {
  if (!minutes || minutes <= 0) return null;
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  if (hours === 0) return `${rest}m`;
  if (rest === 0) return `${hours}h`;
  return `${hours}h ${rest}m`;
}

/**
 * How an availability entry reads in the UI.
 *
 * The media kind only matters for the catch-all: "Watch" is wrong on a
 * book, and a bare link there means we can search a shop, not that it's
 * stocked — so it reads "Find".
 */
export function watchKindLabel(
  kind: "stream" | "rent" | "buy" | "link",
  mediaKind?: MediaKind
): string {
  switch (kind) {
    case "stream":
      return "Stream";
    case "rent":
      return "Rent";
    case "buy":
      return "Buy";
    default:
      return mediaKind === "book" || mediaKind === "album" ? "Find" : "Watch";
  }
}

/** "United Kingdom" from "GB", falling back to the raw code. */
export function regionName(code: string | null): string | null {
  if (!code) return null;
  try {
    return new Intl.DisplayNames(["en"], { type: "region" }).of(code) ?? code;
  } catch {
    return code;
  }
}
