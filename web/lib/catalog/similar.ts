import { toAlbumCandidates } from "@/lib/catalog/musicBrainz";
import { toBookCandidates } from "@/lib/catalog/openLibrary";
import { toMovieCandidates, toShowCandidates } from "@/lib/catalog/tmdb";
import { type MediaCandidate } from "@/lib/catalog/types";
import type { Seed } from "@/lib/recommendations";

const TMDB_BASE = "https://api.themoviedb.org/3";
const OPEN_LIBRARY_BASE = "https://openlibrary.org";
const MUSICBRAINZ_BASE = "https://musicbrainz.org/ws/2";
const USER_AGENT = "Venn/1.0 (social.venn.app)";

/** Catalog responses change slowly; an hour keeps Explorer snappy. */
const REVALIDATE_SECONDS = 3600;

async function getJson(url: string, headers: HeadersInit = {}): Promise<unknown> {
  const response = await fetch(url, { headers, next: { revalidate: REVALIDATE_SECONDS } });
  if (!response.ok) throw new Error(`Catalog request failed: ${response.status}`);
  return await response.json();
}

/**
 * Things like this seed.
 *
 * Film and TV get TMDB's own recommendations, which is real collaborative
 * filtering computed from millions of users — that is what makes this
 * feature work from a user's very first log rather than needing venn to
 * have scale first.
 *
 * Books and music have no equivalent. They fall back to the same subject
 * or the same artist, and the shelf copy says so rather than implying a
 * taste match we cannot support.
 */
export async function fetchSimilar(
  seed: Seed,
  apiKey: string | undefined
): Promise<MediaCandidate[]> {
  if (seed.external_source === "tmdb") {
    if (!apiKey) return [];
    const path = seed.kind === "movie" ? "movie" : "tv";
    const json = await getJson(
      `${TMDB_BASE}/${path}/${seed.external_id}/recommendations?api_key=${apiKey}`
    );
    return seed.kind === "movie" ? toMovieCandidates(json) : toShowCandidates(json);
  }

  if (seed.external_source === "openlibrary") {
    // Two calls: the work to find a subject, then that subject's other
    // books. OpenLibrary has no "similar" endpoint at all.
    const work = (await getJson(`${OPEN_LIBRARY_BASE}/works/${seed.external_id}.json`)) as {
      subjects?: string[];
    };
    const subject = work.subjects?.[0];
    if (!subject) return [];

    const slug = subject.toLowerCase().replace(/\s+/g, "_");
    const json = await getJson(
      `${OPEN_LIBRARY_BASE}/subjects/${encodeURIComponent(slug)}.json?limit=20`
    );
    return toBookCandidates(json);
  }

  // Two calls again: the release-group to find its artist, then that
  // artist's other release-groups. Browsing by artist needs an MBID the
  // seed does not carry.
  const group = (await getJson(
    `${MUSICBRAINZ_BASE}/release-group/${seed.external_id}?inc=artists&fmt=json`,
    { "User-Agent": USER_AGENT }
  )) as { "artist-credit"?: { artist?: { id?: string } }[] };

  const artistId = group["artist-credit"]?.[0]?.artist?.id;
  if (!artistId) return [];

  const json = await getJson(
    `${MUSICBRAINZ_BASE}/release-group?artist=${artistId}&fmt=json&limit=20`,
    { "User-Agent": USER_AGENT }
  );
  // Drop the seed itself — "more from this artist" should not lead with
  // the album you just rated.
  return toAlbumCandidates(json).filter(
    (candidate) => candidate.externalId !== seed.external_id
  );
}

interface TrendingResult {
  id?: number;
  media_type?: string;
  title?: string;
  name?: string;
  release_date?: string;
  first_air_date?: string;
}

/**
 * `/trending/all/week` returns movies, shows **and people** in one list.
 * People are not something you can log, so they are dropped rather than
 * rendered as a coverless card.
 */
export function toTrendingCandidates(json: unknown): MediaCandidate[] {
  const results = (json as { results?: TrendingResult[] } | null)?.results;
  if (!Array.isArray(results)) return [];

  const movies = results.filter((result) => result.media_type === "movie");
  const shows = results.filter((result) => result.media_type === "tv");

  return [...toMovieCandidates({ results: movies }), ...toShowCandidates({ results: shows })];
}

/** What is popular right now. The floor of the ladder — always available. */
export async function fetchTrending(apiKey: string | undefined): Promise<MediaCandidate[]> {
  if (!apiKey) return [];
  return toTrendingCandidates(await getJson(`${TMDB_BASE}/trending/all/week?api_key=${apiKey}`));
}
