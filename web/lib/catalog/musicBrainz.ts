import { candidateId, yearFrom, type MediaCandidate } from "@/lib/catalog/types";

const API_BASE = "https://musicbrainz.org/ws/2";
/**
 * MusicBrainz requires a User-Agent identifying the application and will
 * throttle or block generic ones. A browser can't set this header, which is
 * one reason album search runs server-side (see the Phase 4 spec).
 */
const USER_AGENT = "Venn/1.0 (social.venn.app)";
const PAGE_SIZE = 20;

interface MBReleaseGroup {
  id?: string;
  title?: string;
  "artist-credit"?: { name?: string }[];
  "first-release-date"?: string;
}

/**
 * Cover Art Archive front cover, 500px — the same budget as TMDB's w500.
 * Constructed blind: CAA 404s when no art exists and the tile falls back to
 * its placeholder, so a wrong guess costs nothing.
 */
function coverUrl(releaseGroupId: string): string {
  return `https://coverartarchive.org/release-group/${releaseGroupId}/front-500`;
}

export function toAlbumCandidates(json: unknown): MediaCandidate[] {
  const groups = (json as { "release-groups"?: unknown } | null)?.["release-groups"];
  if (!Array.isArray(groups)) return [];

  return (groups as MBReleaseGroup[])
    .map((group): MediaCandidate | null => {
      if (!group.id || !group.title) return null;

      return {
        id: candidateId("musicbrainz", group.id),
        title: group.title,
        primaryCreator: group["artist-credit"]?.[0]?.name ?? null,
        year: yearFrom(group["first-release-date"]),
        coverUrl: coverUrl(group.id),
        overview: null,
        externalId: group.id,
        externalSource: "musicbrainz",
        kind: "album"
      };
    })
    .filter((candidate): candidate is MediaCandidate => candidate !== null);
}

export async function searchMusicBrainz(query: string): Promise<MediaCandidate[]> {
  const url = `${API_BASE}/release-group?query=${encodeURIComponent(query)}&fmt=json&limit=${PAGE_SIZE}&offset=0`;
  const response = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
  if (!response.ok) throw new Error(`MusicBrainz search failed (${response.status})`);
  return toAlbumCandidates(await response.json());
}
