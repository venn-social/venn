/**
 * The network half of extraction: ask each catalog for one item's raw
 * records, map them, and look up Wikidata QIDs for the people whose
 * identity matters most. Server-only — the TMDB key must never reach a
 * browser. Used by scripts/extract-media-features.ts.
 */

import type { MediaKind } from "@/lib/media";
import { wikidataQid, type ExtractedPerson } from "@/lib/taste/people";
import { musicBrainzFeatures } from "@/lib/taste/providers/musicBrainz";
import { openLibraryFeatures } from "@/lib/taste/providers/openLibrary";
import { tmdbFeatures } from "@/lib/taste/providers/tmdb";
import type { ExtractedFeatures } from "@/lib/taste/record";

const TMDB = "https://api.themoviedb.org/3";
const OPEN_LIBRARY = "https://openlibrary.org";
const MUSICBRAINZ = "https://musicbrainz.org/ws/2";
/** MusicBrainz refuses requests without one. Same identity as the app's. */
const USER_AGENT = "Venn/1.0 (social.venn.app)";
/** MusicBrainz allows one request a second per client; stay under it. */
const MUSICBRAINZ_GAP_MS = 1100;

export interface FetchOptions {
  tmdbApiKey: string | null;
  /** Injected for tests; defaults to global fetch. */
  fetchImpl?: typeof fetch;
  sleep?: (ms: number) => Promise<void>;
}

const wait = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

async function getJson(
  url: string,
  options: FetchOptions,
  headers: Record<string, string> = {}
): Promise<unknown> {
  const response = await (options.fetchImpl ?? fetch)(url, { headers });
  if (!response.ok) throw new Error(`${new URL(url).host} answered ${response.status}`);
  return response.json();
}

/**
 * QIDs are worth a request only for the roles that carry cross-media links
 * (§1.2): a director who also wrote the novel, an author whose book was
 * adapted. Cast would multiply the requests five-fold for links the spec
 * weights at half.
 */
const QID_ROLES = new Set(["director", "author", "primary_artist", "tv_creator", "composer"]);

async function tmdbQid(id: string, options: FetchOptions): Promise<string | undefined> {
  const key = encodeURIComponent(options.tmdbApiKey ?? "");
  const json = (await getJson(
    `${TMDB}/person/${encodeURIComponent(id)}/external_ids?api_key=${key}`,
    options
  )) as {
    wikidata_id?: string | null;
  };
  return wikidataQid(json.wikidata_id);
}

async function openLibraryQid(id: string, options: FetchOptions): Promise<string | undefined> {
  const json = (await getJson(
    `${OPEN_LIBRARY}/authors/${encodeURIComponent(id)}.json`,
    options
  )) as {
    remote_ids?: { wikidata?: string };
  };
  return wikidataQid(json.remote_ids?.wikidata);
}

async function musicBrainzQid(id: string, options: FetchOptions): Promise<string | undefined> {
  await (options.sleep ?? wait)(MUSICBRAINZ_GAP_MS);
  const json = (await getJson(
    `${MUSICBRAINZ}/artist/${encodeURIComponent(id)}?inc=url-rels&fmt=json`,
    options,
    {
      "User-Agent": USER_AGENT
    }
  )) as { relations?: { type?: string; url?: { resource?: string } }[] };
  const relation = (json.relations ?? []).find((rel) => rel.type === "wikidata");
  return wikidataQid(relation?.url?.resource);
}

/** Fill in QIDs where the catalog links one. A failed lookup leaves the catalog id, which is still a valid identity. */
async function withQids(
  people: ExtractedPerson[],
  options: FetchOptions
): Promise<ExtractedPerson[]> {
  const result: ExtractedPerson[] = [];
  for (const entry of people) {
    let qid: string | undefined;
    if (QID_ROLES.has(entry.role)) {
      try {
        if (entry.ids.tmdb && options.tmdbApiKey) qid = await tmdbQid(entry.ids.tmdb, options);
        else if (entry.ids.openlibrary) qid = await openLibraryQid(entry.ids.openlibrary, options);
        else if (entry.ids.musicbrainz) qid = await musicBrainzQid(entry.ids.musicbrainz, options);
      } catch {
        qid = undefined;
      }
    }
    result.push(qid ? { ...entry, ids: { ...entry.ids, wikidata: qid } } : entry);
  }
  return result;
}

async function fetchTmdb(
  kind: "movie" | "show",
  id: string,
  options: FetchOptions
): Promise<ExtractedFeatures> {
  if (!options.tmdbApiKey) throw new Error("TMDB_API_KEY is not set");
  const path = kind === "movie" ? "movie" : "tv";
  const url =
    `${TMDB}/${path}/${encodeURIComponent(id)}?api_key=${encodeURIComponent(options.tmdbApiKey)}` +
    "&append_to_response=credits,keywords";
  return tmdbFeatures(await getJson(url, options), kind);
}

async function fetchOpenLibrary(workId: string, options: FetchOptions): Promise<ExtractedFeatures> {
  const fields =
    "key,first_publish_year,number_of_pages_median,language,subject,author_key,author_name";
  const url = `${OPEN_LIBRARY}/search.json?q=${encodeURIComponent(`key:/works/${workId}`)}&fields=${fields}&limit=1`;
  const json = (await getJson(url, options)) as { docs?: unknown[] };
  const doc = json.docs?.[0];
  if (!doc) throw new Error(`Open Library has no work ${workId}`);
  return openLibraryFeatures(doc);
}

/** The earliest official release: the album as first put out. */
function representativeReleaseId(json: unknown): string | null {
  const releases = (
    (json as { releases?: { id?: string; date?: string; status?: string }[] }).releases ?? []
  )
    .filter((release) => release.id)
    .sort((a, b) => {
      const official = Number(b.status === "Official") - Number(a.status === "Official");
      return official !== 0 ? official : (a.date || "9999").localeCompare(b.date || "9999");
    });
  return releases[0]?.id ?? null;
}

async function fetchMusicBrainz(
  groupId: string,
  options: FetchOptions
): Promise<ExtractedFeatures> {
  const headers = { "User-Agent": USER_AGENT };
  const sleep = options.sleep ?? wait;
  await sleep(MUSICBRAINZ_GAP_MS);
  const group = await getJson(
    `${MUSICBRAINZ}/release-group/${encodeURIComponent(groupId)}?inc=artist-credits+genres+tags+releases&fmt=json`,
    options,
    headers
  );
  const releaseId = representativeReleaseId(group);
  let release: unknown = null;
  if (releaseId) {
    await sleep(MUSICBRAINZ_GAP_MS);
    release = await getJson(
      `${MUSICBRAINZ}/release/${encodeURIComponent(releaseId)}?inc=recordings&fmt=json`,
      options,
      headers
    );
  }
  return musicBrainzFeatures(group, release);
}

export async function fetchFeatures(
  kind: MediaKind,
  source: string,
  externalId: string,
  options: FetchOptions
): Promise<ExtractedFeatures> {
  let extracted: ExtractedFeatures;
  if (source === "tmdb" && (kind === "movie" || kind === "show")) {
    extracted = await fetchTmdb(kind, externalId, options);
  } else if (source === "openlibrary" && kind === "book") {
    extracted = await fetchOpenLibrary(externalId, options);
  } else if (source === "musicbrainz" && kind === "album") {
    extracted = await fetchMusicBrainz(externalId, options);
  } else {
    throw new Error(`no extractor for ${source} ${kind}`);
  }
  return { ...extracted, people: await withQids(extracted.people, options) };
}
