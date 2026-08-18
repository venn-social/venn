import { describe, expect, it } from "vitest";
import {
  amazonDomain,
  providerUrl,
  readOrListenLinks,
  withProviderUrls
} from "@/lib/catalog/destinations";
import type { WatchLink } from "@/lib/catalog/detail";

/**
 * The rule table that replaced catalog links with links to the service.
 *
 * The templates themselves were checked against the live sites by hand;
 * these tests cover the part that can rot silently — matching a provider
 * name to a rule, and building a URL that survives odd titles.
 */

function link(provider: string, url: string | null = null): WatchLink {
  return { provider, kind: "stream", url, logoUrl: null };
}

describe("providerUrl", () => {
  it("sends each provider to its own site, not to a catalog", () => {
    expect(providerUrl("Netflix", "Her", "GB")).toBe("https://www.netflix.com/search?q=Her");
    expect(providerUrl("Hulu", "Her", "US")).toBe("https://www.hulu.com/search?q=Her");
    expect(providerUrl("Disney Plus", "Her", "GB")).toBe(
      "https://www.disneyplus.com/browse/search?q=Her"
    );
  });

  it("treats TMDB's ad and quality tiers as the same website", () => {
    // TMDB lists these as separate providers. They are one site, and a
    // viewer who sees "Netflix Standard with Ads" still just wants Netflix.
    for (const tier of ["Netflix", "Netflix Standard with Ads", "Netflix basic with Ads"]) {
      expect(providerUrl(tier, "Her", "GB")).toBe("https://www.netflix.com/search?q=Her");
    }
  });

  it("prefers the more specific rule when one name contains another", () => {
    // "youtube" is a prefix of "youtubepremium", and Amazon has three
    // spellings across TMDB's data. Ordering is what keeps these apart.
    expect(providerUrl("Amazon Prime Video", "Her", "GB")).toContain("i=instant-video");
    expect(providerUrl("Amazon Video", "Her", "GB")).toContain("i=instant-video");
    expect(providerUrl("YouTube Premium", "Her", "GB")).toContain("youtube.com/results");
  });

  it("uses the viewer's Amazon storefront, so prices are in their currency", () => {
    expect(providerUrl("Amazon Video", "Her", "GB")).toContain("amazon.co.uk");
    expect(providerUrl("Amazon Video", "Her", "FR")).toContain("amazon.fr");
    expect(providerUrl("Amazon Video", "Her", "JP")).toContain("amazon.co.jp");
  });

  it("returns null for a provider we have no verified URL for", () => {
    // An unlinked chip is honest. A guessed URL that 404s is worse than
    // the catalog link this feature replaced.
    expect(providerUrl("Rakuten TV", "Her", "GB")).toBeNull();
    expect(providerUrl("Some New Service", "Her", "GB")).toBeNull();
  });

  it("escapes titles that would otherwise break the query", () => {
    const url = providerUrl("Netflix", "Fast & Furious: Tokyo Drift", "GB");
    expect(url).toBe("https://www.netflix.com/search?q=Fast%20%26%20Furious%3A%20Tokyo%20Drift");
  });
});

describe("withProviderUrls", () => {
  it("keeps TMDB's link for providers it can't reach directly", () => {
    const tmdb = "https://www.themoviedb.org/movie/152601-her/watch?locale=GB";
    const [known, unknown] = withProviderUrls(
      [link("Netflix", tmdb), link("Rakuten TV", tmdb)],
      "Her",
      "GB"
    );

    expect(known.url).toBe("https://www.netflix.com/search?q=Her");
    expect(unknown.url).toBe(tmdb);
  });

  it("leaves everything else about the entry alone", () => {
    const [enriched] = withProviderUrls(
      [{ provider: "Netflix", kind: "rent", url: null, logoUrl: "/logo.png" }],
      "Her",
      "GB"
    );

    expect(enriched.kind).toBe("rent");
    expect(enriched.logoUrl).toBe("/logo.png");
  });
});

describe("readOrListenLinks", () => {
  it("offers shops for a book and services for an album", () => {
    const books = readOrListenLinks("book", "Kafka on the Shore", "Haruki Murakami", "GB");
    expect(books.map((l) => l.provider)).toEqual([
      "Kindle",
      "Amazon",
      "Apple Books",
      "Google Books"
    ]);

    const albums = readOrListenLinks("album", "Kid A", "Radiohead", "GB");
    expect(albums.map((l) => l.provider)).toEqual([
      "Spotify",
      "Apple Music",
      "YouTube Music",
      "Bandcamp"
    ]);
  });

  it("includes the creator, because titles collide", () => {
    // "Kid A" alone is ambiguous on every music service.
    const [spotify] = readOrListenLinks("album", "Kid A", "Radiohead", "GB");
    expect(spotify.url).toBe("https://open.spotify.com/search/Kid%20A%20Radiohead");
  });

  it("works with no creator known", () => {
    const [spotify] = readOrListenLinks("album", "Kid A", null, "GB");
    expect(spotify.url).toBe("https://open.spotify.com/search/Kid%20A");
  });

  it("points Kindle at the digital store and Amazon at print", () => {
    const [kindle, print] = readOrListenLinks("book", "Dune", "Frank Herbert", "US");
    expect(kindle.url).toContain("i=digital-text");
    expect(print.url).toContain("i=stripbooks");
    expect(kindle.kind).toBe("buy");
  });

  it("uses the regional Apple storefront and falls back to US", () => {
    const [, , frBooks] = readOrListenLinks("book", "Dune", null, "FR");
    expect(frBooks.url).toContain("books.apple.com/fr/");

    // An unknown region must not produce books.apple.com//search.
    const [, , unknown] = readOrListenLinks("book", "Dune", null, null);
    expect(unknown.url).toContain("books.apple.com/us/");
  });

  it("has nothing to offer for screen media, which TMDB covers instead", () => {
    expect(readOrListenLinks("movie", "Her", null, "GB")).toEqual([]);
    expect(readOrListenLinks("show", "Severance", null, "GB")).toEqual([]);
  });

  it("offers nothing rather than an empty search when there's no title", () => {
    expect(readOrListenLinks("book", "   ", "Someone", "GB")).toEqual([]);
  });
});

describe("amazonDomain", () => {
  it("falls back to .com for regions with no storefront of their own", () => {
    expect(amazonDomain("GB")).toBe("co.uk");
    expect(amazonDomain("gb")).toBe("co.uk");
    expect(amazonDomain("NO")).toBe("com");
    expect(amazonDomain(null)).toBe("com");
  });
});
