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
    id: candidateId("tmdb", externalId),
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
