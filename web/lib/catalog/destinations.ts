import type { WatchLink } from "@/lib/catalog/detail";
import type { MediaKind } from "@/lib/media";

/**
 * Links that go to the service, not to a catalog page.
 *
 * The three catalogs we read all stop short of this. TMDB names the
 * providers ("Netflix", "Amazon Video") and says whether it's stream, rent
 * or buy, but ships exactly one URL per *region* pointing back at
 * themoviedb.org — there is no per-provider link in the response. Open
 * Library and MusicBrainz carry no purchase or streaming links at all. So
 * "open this on Netflix" is something venn has to construct or not offer.
 *
 * It is built as a rule table rather than stored per item: one entry per
 * provider, applied to every title by filling in its name. Nothing here is
 * specific to a particular film or book, so a title logged tomorrow gets
 * the same treatment as one logged today, with no backfill.
 *
 * These land on the provider's *search* results for the title, not on the
 * title's own page. Deep links need each service's internal id, which none
 * of them publish. A search on Netflix for the exact title is one tap from
 * playing; the TMDB page it replaces was not.
 *
 * Every template below was checked against the live site before it was
 * added. Providers whose search URL could not be confirmed are deliberately
 * absent — an unlinked chip is honest, a 404 is not.
 */

/** How the item is reachable, mirroring TMDB's own distinction. */
type Availability = WatchLink["kind"];

interface Destination {
  /** Name as shown. Matches TMDB's spelling where TMDB is the source. */
  provider: string;
  kind: Availability;
  url: (query: string, region: string) => string;
}

/**
 * Amazon runs a separate storefront per country and a link to the wrong one
 * shows prices in the wrong currency. Regions we don't know fall back to
 * .com rather than guessing a suffix that may not exist.
 */
const AMAZON_DOMAINS: Record<string, string> = {
  AU: "com.au",
  BE: "com.be",
  BR: "com.br",
  CA: "ca",
  DE: "de",
  ES: "es",
  FR: "fr",
  GB: "co.uk",
  IE: "co.uk",
  IN: "in",
  IT: "it",
  JP: "co.jp",
  MX: "com.mx",
  NL: "nl",
  PL: "pl",
  SE: "se",
  SG: "sg",
  TR: "com.tr",
  US: "com"
};

export function amazonDomain(region: string | null): string {
  return AMAZON_DOMAINS[(region ?? "").toUpperCase()] ?? "com";
}

/**
 * Apple's stores are addressed by a lowercase country segment. An unknown
 * one 404s, so anything we don't recognise goes to the US store, which is
 * the one Apple itself falls back to.
 */
function appleStorefront(region: string | null): string {
  const code = (region ?? "").toLowerCase();
  return /^[a-z]{2}$/.test(code) ? code : "us";
}

/**
 * Providers whose search URL is known good, matched against the name TMDB
 * reports. Keys are compared after normalisation, so "Netflix Standard with
 * Ads" and "Netflix basic with Ads" both resolve to Netflix — TMDB lists
 * ad-supported and 4K tiers as separate providers, and they are all the
 * same website.
 *
 * Ordered: the first entry whose key the provider name starts with wins, so
 * longer keys must come first ("amazonprimevideo" before "amazon").
 */
const SCREEN_PROVIDERS: [key: string, url: Destination["url"]][] = [
  ["netflix", (q) => `https://www.netflix.com/search?q=${q}`],
  ["disneyplus", (q) => `https://www.disneyplus.com/browse/search?q=${q}`],
  ["appletv", (q) => `https://tv.apple.com/search?term=${q}`],
  ["itunes", (q) => `https://tv.apple.com/search?term=${q}`],
  ["amazonprimevideo", (q, r) => `https://www.amazon.${amazonDomain(r)}/s?k=${q}&i=instant-video`],
  ["amazonvideo", (q, r) => `https://www.amazon.${amazonDomain(r)}/s?k=${q}&i=instant-video`],
  ["primevideo", (q, r) => `https://www.amazon.${amazonDomain(r)}/s?k=${q}&i=instant-video`],
  ["googleplaymovies", (q) => `https://play.google.com/store/search?q=${q}&c=movies`],
  ["youtubepremium", (q) => `https://www.youtube.com/results?search_query=${q}`],
  ["youtube", (q) => `https://www.youtube.com/results?search_query=${q}`],
  ["hulu", (q) => `https://www.hulu.com/search?q=${q}`],
  ["max", (q) => `https://play.max.com/search?q=${q}`],
  ["hbomax", (q) => `https://play.max.com/search?q=${q}`],
  ["paramountplus", (q) => `https://www.paramountplus.com/search/?q=${q}`],
  ["bbciplayer", (q) => `https://www.bbc.co.uk/iplayer/search?q=${q}`],
  ["mubi", (q, r) => `https://mubi.com/en/${(r ?? "us").toLowerCase()}/search/${q}`]
];

/** Where to read a book. Same list for everyone; the storefront is regional. */
const BOOK_DESTINATIONS: Destination[] = [
  {
    provider: "Kindle",
    kind: "buy",
    url: (q, r) => `https://www.amazon.${amazonDomain(r)}/s?k=${q}&i=digital-text`
  },
  {
    provider: "Amazon",
    kind: "buy",
    url: (q, r) => `https://www.amazon.${amazonDomain(r)}/s?k=${q}&i=stripbooks`
  },
  {
    provider: "Apple Books",
    kind: "buy",
    url: (q, r) => `https://books.apple.com/${appleStorefront(r)}/search?term=${q}`
  },
  {
    provider: "Google Books",
    kind: "link",
    url: (q) => `https://www.google.com/search?q=${q}&tbm=bks`
  }
];

/** Where to listen to an album. */
const ALBUM_DESTINATIONS: Destination[] = [
  { provider: "Spotify", kind: "stream", url: (q) => `https://open.spotify.com/search/${q}` },
  {
    provider: "Apple Music",
    kind: "stream",
    url: (q, r) => `https://music.apple.com/${appleStorefront(r)}/search?term=${q}`
  },
  {
    provider: "YouTube Music",
    kind: "stream",
    url: (q) => `https://music.youtube.com/search?q=${q}`
  },
  { provider: "Bandcamp", kind: "buy", url: (q) => `https://bandcamp.com/search?q=${q}` }
];

/** Lowercased letters and digits only, so spelling and tier drop out. */
function normalise(provider: string): string {
  return provider.toLowerCase().replace(/[^a-z0-9]/g, "");
}

/**
 * The provider's own search page for this title, or null if we don't know
 * the provider. Null keeps the chip unlinked rather than sending someone
 * somewhere wrong.
 */
export function providerUrl(provider: string, title: string, region: string | null): string | null {
  const name = normalise(provider);
  const match = SCREEN_PROVIDERS.find(([key]) => name.startsWith(key));
  if (!match) return null;

  return match[1](encodeURIComponent(title), (region ?? "").toUpperCase());
}

/**
 * TMDB's availability, pointed at the providers themselves.
 *
 * Keeps TMDB's region link as the fallback for providers we can't reach
 * directly: it still answers "where do I watch this", just with a stop on
 * the way.
 */
export function withProviderUrls(
  links: WatchLink[],
  title: string,
  region: string | null
): WatchLink[] {
  return links.map((link) => ({
    ...link,
    url: providerUrl(link.provider, title, region) ?? link.url
  }));
}

/**
 * Where to read or listen to something, built from the title and creator
 * alone.
 *
 * Books and albums have no availability data anywhere we look, so unlike
 * the screen list this is not a claim that the item is stocked — it is a
 * search we can run for you. The UI says so.
 *
 * The creator is part of the query because titles collide badly: "Kid A"
 * alone is ambiguous on every music service, "Kid A Radiohead" is not.
 */
export function readOrListenLinks(
  kind: MediaKind,
  title: string,
  creator: string | null,
  region: string | null
): WatchLink[] {
  const destinations =
    kind === "book" ? BOOK_DESTINATIONS : kind === "album" ? ALBUM_DESTINATIONS : [];
  if (destinations.length === 0 || !title.trim()) return [];

  const query = encodeURIComponent([title, creator].filter(Boolean).join(" ").trim());
  const upper = (region ?? "").toUpperCase();

  return destinations.map((destination) => ({
    provider: destination.provider,
    kind: destination.kind,
    url: destination.url(query, upper),
    logoUrl: null
  }));
}
