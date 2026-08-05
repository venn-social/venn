import type { SupabaseClient } from "@supabase/supabase-js";
import { EMPTY_DETAIL, sourceUrlFor, type MediaDetail } from "@/lib/catalog/detail";
import { fetchMusicBrainzDetail } from "@/lib/catalog/musicBrainz";
import { fetchOpenLibraryDetail } from "@/lib/catalog/openLibrary";
import { fetchTMDBDetail } from "@/lib/catalog/tmdb";
import { toMedia, type Media, type MediaRow } from "@/lib/media";

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
    return { ...detail, sourceUrl };
  } catch {
    // Still give them the link out, even if we couldn't enrich.
    return { ...EMPTY_DETAIL, sourceUrl };
  }
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

/** How an availability entry reads in the UI. */
export function watchKindLabel(kind: "stream" | "rent" | "buy" | "link"): string {
  switch (kind) {
    case "stream":
      return "Stream";
    case "rent":
      return "Rent";
    case "buy":
      return "Buy";
    default:
      return "Watch";
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
