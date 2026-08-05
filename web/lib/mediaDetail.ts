import type { SupabaseClient } from "@supabase/supabase-js";
import { EMPTY_DETAIL, type MediaDetail } from "@/lib/catalog/detail";
import { toMedia, type Media, type MediaRow } from "@/lib/media";

/** One catalog row by id. Null when it doesn't exist — the page 404s. */
export async function fetchMediaById(
  client: SupabaseClient,
  mediaId: string
): Promise<Media | null> {
  const { data, error } = await client
    .from("media")
    .select("*")
    .eq("id", mediaId)
    .maybeSingle();

  if (error) {
    if (error.code === "22P02") return null; // junk uuid in the URL
    throw error;
  }
  return data ? toMedia(data as MediaRow) : null;
}

/**
 * Enriched detail from whichever catalog this row came from.
 *
 * Returns the empty shape rather than throwing when the item has no
 * external source (someone typed it by hand) or the provider is down. The
 * page still has the title, cover, year, and creator from our own row —
 * a degraded detail section beats a broken page.
 */
export async function fetchMediaDetail(
  media: Media,
  origin: string,
  headers: HeadersInit
): Promise<MediaDetail> {
  if (!media.externalSource || !media.externalId) return EMPTY_DETAIL;

  const params = new URLSearchParams({
    source: media.externalSource,
    externalId: media.externalId,
    kind: media.kind
  });

  try {
    const response = await fetch(`${origin}/api/catalog/detail?${params.toString()}`, {
      headers,
      // Detail changes rarely — an hour of caching spares the provider and
      // makes a second visit instant.
      next: { revalidate: 3600 }
    });
    if (!response.ok) return EMPTY_DETAIL;

    const json = await response.json();
    return (json.detail as MediaDetail) ?? EMPTY_DETAIL;
  } catch {
    return EMPTY_DETAIL;
  }
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
