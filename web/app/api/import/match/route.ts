import { NextResponse, type NextRequest } from "next/server";
import { searchOpenLibrary } from "@/lib/catalog/openLibrary";
import { searchTMDB } from "@/lib/catalog/tmdb";
import {
  MAX_MATCH_REQUEST,
  matchEntries,
  type CatalogLookup,
  type MatchableEntry
} from "@/lib/import/matchEntries";
import { DEFAULT_LANGUAGE } from "@/lib/language";
import { sanitizeSearchQuery } from "@/lib/sanitize";
import { createClient } from "@/lib/supabase/server";

/** Kinds an import can match today. */
const IMPORT_KINDS = ["movie", "book"] as const;

const ISBN = /^(\d{13}|\d{9}[\dX])$/;

/**
 * Matches a batch of import rows against the catalog. Server-side for the
 * same reasons as /api/catalog/search: the TMDB key stays off the browser,
 * and there is one place to rate-limit. Batched so a 600-film export is ~24
 * requests rather than 600, each rate-limited once.
 */
export async function POST(request: NextRequest) {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: "Sign in to import." }, { status: 401 });
  }

  const entries = parseEntries(await request.json().catch(() => null));
  if (!entries) {
    return NextResponse.json({ error: "Malformed import batch." }, { status: 400 });
  }

  const { data: allowed, error: limitError } = await supabase.rpc("rl_check_self", {
    _action: "import_match",
    _limit: 60,
    _window: "00:01:00"
  });
  if (!limitError && allowed === false) {
    return NextResponse.json({ error: "Too many requests — give it a moment." }, { status: 429 });
  }

  const apiKey = process.env.TMDB_API_KEY;
  if (!apiKey && entries.some((entry) => entry.kind !== "book")) {
    return NextResponse.json({ error: "Movie matching needs a TMDB API key." }, { status: 502 });
  }

  // English on purpose: Letterboxd exports carry English/original titles,
  // and matching compares titles, so asking TMDB for a translation would
  // turn exact matches into misses. Open Library takes no language.
  const lookup: CatalogLookup = {
    search: (kind, query) =>
      kind === "book"
        ? searchOpenLibrary(query)
        : searchTMDB(kind === "show" ? "show" : "movie", query, apiKey ?? "", DEFAULT_LANGUAGE)
  };
  return NextResponse.json({ matches: await matchEntries(entries, lookup) });
}

function parseEntries(body: unknown): MatchableEntry[] | null {
  const raw = (body as { entries?: unknown } | null)?.entries;
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > MAX_MATCH_REQUEST) return null;

  const entries: MatchableEntry[] = [];
  for (const item of raw) {
    const { kind, title, year, creator, isbn } = (item ?? {}) as Record<string, unknown>;
    if (!IMPORT_KINDS.includes(kind as (typeof IMPORT_KINDS)[number])) return null;
    if (typeof title !== "string") return null;
    const cleaned = sanitizeSearchQuery(title);
    if (!cleaned.valid || !cleaned.value) return null;
    if (year !== null && year !== undefined && !Number.isInteger(year)) return null;

    let cleanedCreator: string | null = null;
    if (typeof creator === "string") {
      const result = sanitizeSearchQuery(creator);
      if (!result.valid) return null;
      cleanedCreator = result.value || null;
    }
    // Only digits reach the "isbn:" query, so nothing else can be smuggled
    // into Open Library's search syntax.
    if (isbn !== null && isbn !== undefined && (typeof isbn !== "string" || !ISBN.test(isbn)))
      return null;

    entries.push({
      kind: kind as MatchableEntry["kind"],
      title: cleaned.value,
      year: (year as number | null | undefined) ?? null,
      creator: cleanedCreator,
      isbn: (isbn as string | null | undefined) ?? null
    });
  }
  return entries;
}
