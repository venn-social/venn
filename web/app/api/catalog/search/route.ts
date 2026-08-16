import { NextResponse, type NextRequest } from "next/server";
import { searchMusicBrainz } from "@/lib/catalog/musicBrainz";
import { searchOpenLibrary } from "@/lib/catalog/openLibrary";
import { toLanguage, type LanguageCode } from "@/lib/language";
import { searchTMDB } from "@/lib/catalog/tmdb";
import { createClient } from "@/lib/supabase/server";

const KINDS = ["movie", "show", "book", "album"] as const;
type Kind = (typeof KINDS)[number];

/**
 * Catalog search. Runs server-side for three reasons: TMDB_API_KEY never
 * reaches the browser, MusicBrainz needs a User-Agent a browser can't set,
 * and one endpoint gives one place to rate-limit.
 *
 * Requires a session — an unauthenticated proxy to the TMDB quota is exactly
 * the risk being avoided.
 */
export async function GET(request: NextRequest) {
  const kind = request.nextUrl.searchParams.get("kind");
  const query = request.nextUrl.searchParams.get("q")?.trim();

  if (!kind || !KINDS.includes(kind as Kind)) {
    return NextResponse.json({ error: "Unknown media kind." }, { status: 400 });
  }
  if (!query) {
    return NextResponse.json({ candidates: [] });
  }

  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Sign in to search." }, { status: 401 });
  }

  // Sliding window in Postgres, not in memory: Route Handlers run
  // serverless, so an in-process counter resets on cold start and isn't
  // shared between instances — it would enforce nothing.
  // rl_check_self, not rl_check: the key-taking version let any signed-in
  // caller spend somebody else's allowance. This one derives the identity
  // from auth.uid(), which cannot be forged from the client.
  const { data: allowed, error: limitError } = await supabase.rpc("rl_check_self", {
    _action: "catalog_search",
    _limit: 60,
    _window: "00:01:00"
  });
  if (!limitError && allowed === false) {
    return NextResponse.json({ error: "Too many searches — give it a moment." }, { status: 429 });
  }

  try {
    // One extra read by primary key, so the results come back in the
    // language this person actually reads.
    const { data: profile } = await supabase
      .from("profiles")
      .select("language")
      .eq("id", user.id)
      .maybeSingle();

    const candidates = await searchFor(kind as Kind, query, toLanguage(profile?.language));
    return NextResponse.json({ candidates });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Search failed.";
    return NextResponse.json({ error: message }, { status: 502 });
  }
}

async function searchFor(kind: Kind, query: string, language: LanguageCode) {
  // Only TMDB is asked for a language. Open Library already answers with the
  // edition that matched the query, and MusicBrainz does not translate
  // release titles at all — passing a language there would imply a promise
  // neither provider keeps.
  if (kind === "book") return searchOpenLibrary(query);
  if (kind === "album") return searchMusicBrainz(query);

  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey) {
    // Mirrors iOS's AppError.validation for the same missing-key case.
    throw new Error("Movie and show search needs a TMDB API key.");
  }
  return searchTMDB(kind, query, apiKey, language);
}
