// No yearFrom here: OpenLibrary returns first_publish_year already numeric,
// unlike TMDB's and MusicBrainz's date strings.
import { candidateId, type MediaCandidate } from "@/lib/catalog/types";

const API_BASE = "https://openlibrary.org";
const COVERS_BASE = "https://covers.openlibrary.org/b/id";

interface OLDoc {
  key?: string;
  title?: string;
  author_name?: string[];
  first_publish_year?: number;
  cover_i?: number;
  // Some records return {value}, others a bare string.
  first_sentence?: { value?: string } | string;
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
      const externalId = doc.key.replace(/^\/works\//, "");

      return {
        id: candidateId("openlibrary", externalId),
        title: doc.title,
        primaryCreator: doc.author_name?.[0] ?? null,
        year: doc.first_publish_year ?? null,
        coverUrl: doc.cover_i ? `${COVERS_BASE}/${doc.cover_i}-M.jpg` : null,
        overview: firstSentence(doc),
        externalId,
        externalSource: "openlibrary",
        kind: "book"
      };
    })
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

export async function searchOpenLibrary(query: string): Promise<MediaCandidate[]> {
  const url = `${API_BASE}/search.json?q=${encodeURIComponent(query)}&page=1`;
  const response = await fetch(url);
  if (!response.ok) throw new Error(`OpenLibrary search failed (${response.status})`);
  return toBookCandidates(await response.json());
}
