// No yearFrom here: OpenLibrary returns first_publish_year already numeric,
// unlike TMDB's and MusicBrainz's date strings.
import { isLatinScript, preferredAuthorName } from "@/lib/catalog/authorName";
import { EMPTY_DETAIL, type MediaDetail } from "@/lib/catalog/detail";
import { candidateId, type MediaCandidate } from "@/lib/catalog/types";

const API_BASE = "https://openlibrary.org";
const COVERS_BASE = "https://covers.openlibrary.org/b/id";

interface OLEdition {
  title?: string;
  cover_i?: number;
  language?: string[];
}

interface OLDoc {
  key?: string;
  title?: string;
  author_name?: string[];
  first_publish_year?: number;
  cover_i?: number;
  // Some records return {value}, others a bare string.
  first_sentence?: { value?: string } | string;
  /** Populated by `fields=*,editions` — see `presentation()`. */
  editions?: { docs?: OLEdition[] };
  author_key?: string[];
}

/**
 * A page of twenty foreign-language results should not become twenty extra
 * requests; Open Library rate-limits hard and answers with an empty 200
 * when it does.
 */
const AUTHOR_LOOKUP_LIMIT = 5;

/**
 * The title and cover to show for a search hit.
 *
 * Open Library's `title` is the *work's* canonical title, which is the
 * original language — so searching "kafka on the shore" returns
 * 海辺のカフカ, and "perfume" returns Das Parfum. Asking for
 * `fields=*,editions` makes the response carry the edition that actually
 * matched the query, which is the one the searcher meant.
 *
 * Title and cover are taken together, never mixed. Showing "The Stranger"
 * over the French cover would be a worse result than the French title,
 * because it looks like the wrong book rather than another language.
 */
export function presentation(doc: OLDoc): { title: string; coverId: number | null } {
  const workTitle = doc.title ?? "";
  const edition = doc.editions?.docs?.[0];

  if (edition?.title) {
    return { title: edition.title, coverId: edition.cover_i ?? doc.cover_i ?? null };
  }
  return { title: workTitle, coverId: doc.cover_i ?? null };
}

function firstSentence(doc: OLDoc): string | null {
  if (typeof doc.first_sentence === "string") return doc.first_sentence || null;
  return doc.first_sentence?.value || null;
}

export function toBookCandidates(json: unknown): MediaCandidate[] {
  const docs = (json as { docs?: unknown } | null)?.docs;
  if (!Array.isArray(docs)) return [];

  return (docs as OLDoc[])
    .map((doc): MediaCandidate | null => {
      if (!doc.key || !doc.title) return null;
      // "/works/OL123W" → "OL123W"; a bare key passes through untouched.
      // Deliberately still the *work* key even when an edition supplies the
      // title: identity is what media rows and the recommendation exclusion
      // are keyed on, and re-pointing it would orphan every book already
      // logged.
      const externalId = doc.key.replace(/^\/works\//, "");
      const { title, coverId } = presentation(doc);

      return {
        id: candidateId("openlibrary", "book", externalId),
        title,
        primaryCreator: doc.author_name?.[0] ?? null,
        year: doc.first_publish_year ?? null,
        // -L (465x475), not -M (180x183) — a medium cover is smaller than
        // the tile it renders into, so every book was upscaled. Served via
        // a 302 the browser follows.
        coverUrl: coverId ? `${COVERS_BASE}/${coverId}-L.jpg` : null,
        overview: firstSentence(doc),
        externalId,
        externalSource: "openlibrary",
        kind: "book"
      };
    })
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

export async function searchOpenLibrary(query: string): Promise<MediaCandidate[]> {
  // `fields=*,editions` is what makes the response carry the edition that
  // matched the query, rather than only the work's original-language title.
  const url =
    `${API_BASE}/search.json?q=${encodeURIComponent(query)}&page=1` + `&fields=*,editions`;
  const response = await fetch(url);
  if (!response.ok) throw new Error(`OpenLibrary search failed (${response.status})`);
  const json = await response.json();
  return withLatinAuthors(toBookCandidates(json), json);
}

/**
 * Replace author names written in another script with their Latin form.
 *
 * The search response only carries the name as printed on the book, so a
 * Japanese author arrives as 村上春樹. The Latin form lives on the author
 * record, which costs one request — but only for the credits that actually
 * need it, which is nearly always none.
 *
 * This runs at search time on purpose. `primary_creator` is copied into
 * `media` when something is logged, so fixing it only on the detail screen
 * would leave every shelf and feed row still unreadable.
 */
async function withLatinAuthors(
  candidates: MediaCandidate[],
  json: unknown
): Promise<MediaCandidate[]> {
  const docs = ((json as { docs?: OLDoc[] } | null)?.docs ?? []) as OLDoc[];

  const keysNeeded: string[] = [];
  candidates.forEach((candidate, index) => {
    const creator = candidate.primaryCreator;
    if (!creator || isLatinScript(creator)) return;
    const key = docs[index]?.author_key?.[0];
    if (key && !keysNeeded.includes(key)) keysNeeded.push(key);
  });
  if (keysNeeded.length === 0) return candidates;

  const resolved = new Map<string, string>();
  await Promise.all(
    keysNeeded.slice(0, AUTHOR_LOOKUP_LIMIT).map(async (key) => {
      try {
        const response = await fetch(`${API_BASE}/authors/${key}.json`);
        if (!response.ok) return;
        const record = (await response.json()) as { name?: string; personal_name?: string };
        const preferred = preferredAuthorName(record.name, record.personal_name);
        // A failed or still-unreadable lookup leaves the original name
        // rather than failing the search.
        if (preferred && isLatinScript(preferred)) resolved.set(key, preferred);
      } catch {
        // Ignored — see above.
      }
    })
  );
  if (resolved.size === 0) return candidates;

  return candidates.map((candidate, index) => {
    const key = docs[index]?.author_key?.[0];
    const latin = key ? resolved.get(key) : undefined;
    return latin ? { ...candidate, primaryCreator: latin } : candidate;
  });
}

// ---------------------------------------------------------------------------
// Detail
// ---------------------------------------------------------------------------

interface OLWork {
  // OpenLibrary returns description as either a bare string or {value},
  // depending on how old the record is.
  description?: { value?: string } | string;
  subjects?: string[];
  first_publish_date?: string;
  authors?: { author?: { key?: string } }[];
}

function workDescription(work: OLWork): string | null {
  if (typeof work.description === "string") return work.description || null;
  return work.description?.value || null;
}

export function toBookDetail(work: unknown, authorNames: string[]): MediaDetail {
  const parsed = (work ?? {}) as OLWork;

  return {
    ...EMPTY_DETAIL,
    overview: workDescription(parsed),
    // Books have authors, not a cast — they go in creators, and credits
    // stays empty rather than duplicating them.
    creators: authorNames.map((name) => ({ name, role: "Author" })),
    // Subjects are OpenLibrary's genres, and there are often dozens; the
    // first handful are the useful ones.
    genres: (parsed.subjects ?? []).slice(0, 8),
    releaseDate: parsed.first_publish_date || null
  };
}

/**
 * A work plus its authors. OpenLibrary stores authors by reference, so
 * their names need a second round of lookups — done in parallel, and a
 * failed one is skipped rather than failing the page.
 */
export async function fetchOpenLibraryDetail(externalId: string): Promise<MediaDetail> {
  const response = await fetch(`${API_BASE}/works/${encodeURIComponent(externalId)}.json`);
  if (!response.ok) throw new Error(`OpenLibrary detail failed (${response.status})`);

  const work = (await response.json()) as OLWork;
  const keys = (work.authors ?? [])
    .map((entry) => entry.author?.key)
    .filter((key): key is string => Boolean(key))
    .slice(0, 5);

  const names = await Promise.all(
    keys.map(async (key) => {
      try {
        const authorResponse = await fetch(`${API_BASE}${key}.json`);
        if (!authorResponse.ok) return null;
        const author = (await authorResponse.json()) as {
          name?: string;
          personal_name?: string;
        };
        return preferredAuthorName(author.name, author.personal_name);
      } catch {
        return null;
      }
    })
  );

  return toBookDetail(work, names.filter((name): name is string => Boolean(name)));
}
