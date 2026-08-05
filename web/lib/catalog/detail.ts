import type { ExternalSource } from "@/lib/catalog/types";
import type { MediaKind } from "@/lib/media";

/** One credited person — an actor, author, or artist. */
export interface Credit {
  name: string;
  /** The character played, for screen credits. Null elsewhere. */
  role: string | null;
}

/** Somewhere you can watch or listen to this. */
export interface WatchLink {
  provider: string;
  /**
   * How it's available: streaming with a subscription, rent, buy, or a
   * direct link out to the provider. TMDB distinguishes these and they
   * matter — "on Netflix" and "£13.99 to buy" are different answers.
   */
  kind: "stream" | "rent" | "buy" | "link";
  url: string | null;
  logoUrl: string | null;
}

/**
 * Everything worth knowing about one title, normalized across providers.
 *
 * Every field is optional because the three catalogs disagree wildly about
 * what they hold: TMDB has cast and runtime, OpenLibrary has page counts
 * and subjects, MusicBrainz has neither but knows the label. Rendering
 * skips whatever is missing rather than showing blanks.
 */
export interface MediaDetail {
  overview: string | null;
  /** Actors for screen, authors for books, artists for music. */
  credits: Credit[];
  /** Directors, showrunners — the authorial credit, kept separate from cast. */
  creators: Credit[];
  genres: string[];
  /** Minutes for screen; null elsewhere. */
  runtime: number | null;
  /** Pages for books; null elsewhere. */
  pageCount: number | null;
  releaseDate: string | null;
  /** Out of 10, as TMDB reports it. Null when unrated or unsupported. */
  rating: number | null;
  watchLinks: WatchLink[];
  /** ISO country the watch links apply to — availability is regional. */
  watchRegion: string | null;
  /** Deep link back to the source, so people can go read more. */
  sourceUrl: string | null;
}

export const EMPTY_DETAIL: MediaDetail = {
  overview: null,
  credits: [],
  creators: [],
  genres: [],
  runtime: null,
  pageCount: null,
  releaseDate: null,
  rating: null,
  watchLinks: [],
  watchRegion: null,
  sourceUrl: null
};

/**
 * Where to send someone who wants the full record. Each provider has a
 * public page per item, and linking out is more honest than pretending we
 * hold everything.
 */
export function sourceUrlFor(
  source: ExternalSource,
  kind: MediaKind,
  externalId: string
): string | null {
  switch (source) {
    case "tmdb":
      return `https://www.themoviedb.org/${kind === "movie" ? "movie" : "tv"}/${externalId}`;
    case "openlibrary":
      return `https://openlibrary.org/works/${externalId}`;
    case "musicbrainz":
      return `https://musicbrainz.org/release-group/${externalId}`;
    default:
      return null;
  }
}

/**
 * The region whose availability we show.
 *
 * Vercel sets `x-vercel-ip-country` from the edge; falling back to the
 * browser's `Accept-Language` region covers local development and any host
 * that doesn't geolocate. Defaults to GB.
 *
 * Getting this wrong is a wrong answer, not a broken page — which is why
 * the UI always states the region it used rather than implying the list is
 * universal.
 */
export function regionFrom(headers: Headers): string {
  const geo = headers.get("x-vercel-ip-country");
  if (geo && /^[A-Za-z]{2}$/.test(geo)) return geo.toUpperCase();

  const language = headers.get("accept-language");
  const region = language?.match(/[a-z]{2,3}-([A-Z]{2})/)?.[1];
  if (region) return region.toUpperCase();

  return "GB";
}
