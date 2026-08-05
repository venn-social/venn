import { NextResponse, type NextRequest } from "next/server";
import { EMPTY_DETAIL, regionFrom, sourceUrlFor } from "@/lib/catalog/detail";
import { fetchMusicBrainzDetail } from "@/lib/catalog/musicBrainz";
import { fetchOpenLibraryDetail } from "@/lib/catalog/openLibrary";
import { fetchTMDBDetail } from "@/lib/catalog/tmdb";
import type { ExternalSource } from "@/lib/catalog/types";
import { MEDIA_KINDS, type MediaKind } from "@/lib/media";
import { createClient } from "@/lib/supabase/server";

const SOURCES: readonly string[] = ["tmdb", "openlibrary", "musicbrainz"];

/**
 * Rich detail for one catalog item: description, credits, genres, and —
 * for screen — where to watch it.
 *
 * Server-side for the same reasons as the search endpoint: TMDB_API_KEY
 * never reaches the browser, MusicBrainz needs a User-Agent a browser
 * can't set, and one endpoint means one place to rate-limit.
 *
 * Availability is regional, so the region is resolved from the request and
 * returned alongside the links — a list of providers without saying where
 * they apply is worse than none.
 */
export async function GET(request: NextRequest) {
  const params = request.nextUrl.searchParams;
  const source = params.get("source");
  const externalId = params.get("externalId");
  const kind = params.get("kind");

  if (!source || !SOURCES.includes(source)) {
    return NextResponse.json({ error: "Unknown source." }, { status: 400 });
  }
  if (!kind || !MEDIA_KINDS.includes(kind)) {
    return NextResponse.json({ error: "Unknown media kind." }, { status: 400 });
  }
  if (!externalId) {
    return NextResponse.json({ error: "Missing externalId." }, { status: 400 });
  }

  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Sign in to see details." }, { status: 401 });
  }

  // Sliding window in Postgres, not in memory: Route Handlers run
  // serverless, so an in-process counter resets on cold start.
  const { data: allowed, error: limitError } = await supabase.rpc("rl_check", {
    _key: `catalog_detail:${user.id}`,
    _limit: 120,
    _window: "00:01:00"
  });
  if (!limitError && allowed === false) {
    return NextResponse.json({ error: "Too many requests — give it a moment." }, { status: 429 });
  }

  const region = regionFrom(request.headers);

  try {
    const detail = await fetchDetail(
      source as ExternalSource,
      kind as MediaKind,
      externalId,
      region
    );
    return NextResponse.json({
      detail: { ...detail, sourceUrl: sourceUrlFor(source as ExternalSource, kind as MediaKind, externalId) }
    });
  } catch {
    // A provider being down shouldn't blank the page — the caller still has
    // the title, cover, and year from our own database.
    return NextResponse.json({
      detail: {
        ...EMPTY_DETAIL,
        sourceUrl: sourceUrlFor(source as ExternalSource, kind as MediaKind, externalId)
      },
      degraded: true
    });
  }
}

function fetchDetail(
  source: ExternalSource,
  kind: MediaKind,
  externalId: string,
  region: string
) {
  if (source === "openlibrary") return fetchOpenLibraryDetail(externalId);
  if (source === "musicbrainz") return fetchMusicBrainzDetail(externalId);

  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey) throw new Error("Movie and show details need a TMDB API key.");
  return fetchTMDBDetail(kind === "movie" ? "movie" : "show", externalId, apiKey, region);
}
