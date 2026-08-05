import {
  EMPTY_DETAIL,
  type MediaDetail,
  type WatchLink
} from "@/lib/catalog/detail";
import { candidateId, yearFrom, type MediaCandidate } from "@/lib/catalog/types";

const API_BASE = "https://api.themoviedb.org/3";
/** Same pixel budget as TMDBService.posterBase. */
const POSTER_BASE = "https://image.tmdb.org/t/p/w500";

interface TMDBResult {
  id?: number;
  title?: string;
  name?: string;
  release_date?: string | null;
  first_air_date?: string | null;
  poster_path?: string | null;
  overview?: string | null;
}

function resultsOf(json: unknown): TMDBResult[] {
  const results = (json as { results?: unknown } | null)?.results;
  return Array.isArray(results) ? (results as TMDBResult[]) : [];
}

function toCandidate(result: TMDBResult, kind: "movie" | "show"): MediaCandidate | null {
  // TMDB names these fields differently for film and television.
  const title = kind === "movie" ? result.title : result.name;
  const date = kind === "movie" ? result.release_date : result.first_air_date;
  if (result.id === undefined || !title) return null;

  const externalId = String(result.id);
  return {
    id: candidateId("tmdb", kind, externalId),
    title,
    primaryCreator: null,
    year: yearFrom(date),
    coverUrl: result.poster_path ? `${POSTER_BASE}${result.poster_path}` : null,
    overview: result.overview || null,
    externalId,
    externalSource: "tmdb",
    kind
  };
}

export function toMovieCandidates(json: unknown): MediaCandidate[] {
  return resultsOf(json)
    .map((result) => toCandidate(result, "movie"))
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

export function toShowCandidates(json: unknown): MediaCandidate[] {
  return resultsOf(json)
    .map((result) => toCandidate(result, "show"))
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

/** Server-only: `apiKey` must never be passed from a client component. */
export async function searchTMDB(
  kind: "movie" | "show",
  query: string,
  apiKey: string
): Promise<MediaCandidate[]> {
  const path = kind === "movie" ? "movie" : "tv";
  const url = `${API_BASE}/search/${path}?api_key=${encodeURIComponent(apiKey)}&query=${encodeURIComponent(query)}&page=1`;

  const response = await fetch(url);
  if (!response.ok) throw new Error(`TMDB search failed (${response.status})`);

  const json: unknown = await response.json();
  return kind === "movie" ? toMovieCandidates(json) : toShowCandidates(json);
}

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

const IMAGE_BASE = "https://image.tmdb.org/t/p/w92";

interface TMDBPerson {
  name?: string;
  character?: string;
  job?: string;
}

interface TMDBProvider {
  provider_name?: string;
  logo_path?: string | null;
}

interface TMDBDetailResponse {
  overview?: string | null;
  runtime?: number;
  episode_run_time?: number[];
  genres?: { name?: string }[];
  release_date?: string;
  first_air_date?: string;
  vote_average?: number;
  credits?: { cast?: TMDBPerson[]; crew?: TMDBPerson[] };
  created_by?: TMDBPerson[];
  "watch/providers"?: {
    results?: Record<
      string,
      { link?: string; flatrate?: TMDBProvider[]; rent?: TMDBProvider[]; buy?: TMDBProvider[] }
    >;
  };
}

function toWatchLinks(json: TMDBDetailResponse, region: string): WatchLink[] {
  const forRegion = json["watch/providers"]?.results?.[region];
  if (!forRegion) return [];

  const link = forRegion.link ?? null;
  const groups: [TMDBProvider[] | undefined, WatchLink["kind"]][] = [
    [forRegion.flatrate, "stream"],
    [forRegion.rent, "rent"],
    [forRegion.buy, "buy"]
  ];

  const seen = new Set<string>();
  const links: WatchLink[] = [];
  for (const [providers, kind] of groups) {
    for (const provider of providers ?? []) {
      const name = provider.provider_name;
      // A provider often appears under several kinds; the first (and
      // cheapest — stream before rent before buy) is the useful answer.
      if (!name || seen.has(name)) continue;
      seen.add(name);
      links.push({
        provider: name,
        kind,
        // TMDB gives one link per region, not per provider — it lands on
        // their own "where to watch" page rather than deep-linking.
        url: link,
        logoUrl: provider.logo_path ? `${IMAGE_BASE}${provider.logo_path}` : null
      });
    }
  }
  return links;
}

export function toMovieDetail(json: unknown, region: string): MediaDetail {
  const detail = (json ?? {}) as TMDBDetailResponse;

  return {
    ...EMPTY_DETAIL,
    overview: detail.overview || null,
    credits: (detail.credits?.cast ?? [])
      .slice(0, 12)
      .filter((person): person is TMDBPerson & { name: string } => Boolean(person.name))
      .map((person) => ({ name: person.name, role: person.character || null })),
    // Directors for film, creators for television — the authorial credit,
    // kept apart from cast because they answer a different question.
    creators: (detail.created_by ?? [])
      .concat((detail.credits?.crew ?? []).filter((person) => person.job === "Director"))
      .filter((person): person is TMDBPerson & { name: string } => Boolean(person.name))
      .map((person) => ({ name: person.name, role: person.job || "Director" })),
    genres: (detail.genres ?? [])
      .map((genre) => genre.name)
      .filter((name): name is string => Boolean(name)),
    runtime: detail.runtime ?? detail.episode_run_time?.[0] ?? null,
    releaseDate: detail.release_date || detail.first_air_date || null,
    rating: typeof detail.vote_average === "number" ? detail.vote_average : null,
    watchLinks: toWatchLinks(detail, region),
    watchRegion: region
  };
}

/** Server-only. One call fetches credits and availability alongside the record. */
export async function fetchTMDBDetail(
  kind: "movie" | "show",
  externalId: string,
  apiKey: string,
  region: string
): Promise<MediaDetail> {
  const path = kind === "movie" ? "movie" : "tv";
  const url = `${API_BASE}/${path}/${encodeURIComponent(externalId)}?api_key=${encodeURIComponent(apiKey)}&append_to_response=credits,watch/providers`;

  const response = await fetch(url);
  if (!response.ok) throw new Error(`TMDB detail failed (${response.status})`);

  return toMovieDetail(await response.json(), region);
}
