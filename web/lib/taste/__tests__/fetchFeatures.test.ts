import { describe, expect, it, vi } from "vitest";
import { fetchFeatures } from "@/lib/taste/fetchFeatures";
import {
  MB_BLUE_GROUP,
  MB_BLUE_RELEASE,
  OL_KLARA,
  TMDB_PAST_LIVES
} from "@/lib/taste/__tests__/fixtures";

function fakeFetch(routes: [RegExp, unknown][]) {
  return vi.fn(async (input: string | URL | Request) => {
    const url = String(input);
    const match = routes.find(([pattern]) => pattern.test(url));
    if (!match) return new Response("not found", { status: 404 });
    return new Response(JSON.stringify(match[1]), { status: 200 });
  }) as unknown as typeof fetch & ReturnType<typeof vi.fn>;
}

const noSleep = async () => {};

describe("fetchFeatures", () => {
  it("asks TMDB once for the record, then for QIDs of authorial roles only", async () => {
    const fetchImpl = fakeFetch([
      [/\/movie\/666277\?/, TMDB_PAST_LIVES],
      [/\/person\/2340979\/external_ids/, { wikidata_id: "Q107381212" }],
      [/\/person\/\d+\/external_ids/, { wikidata_id: null }]
    ]);
    const features = await fetchFeatures("movie", "tmdb", "666277", {
      tmdbApiKey: "k",
      fetchImpl,
      sleep: noSleep
    });

    const director = features.people.find((p) => p.role === "director");
    expect(director?.ids).toEqual({ tmdb: "2340979", wikidata: "Q107381212" });
    const urls = fetchImpl.mock.calls.map(([url]) => String(url));
    expect(urls[0]).toContain("append_to_response=credits,keywords");
    // director, screenwriter skipped (not a linking role), composer; no cast.
    expect(urls.filter((url) => url.includes("external_ids"))).toHaveLength(2);
  });

  it("refuses TMDB work without a key instead of sending an empty one", async () => {
    await expect(
      fetchFeatures("movie", "tmdb", "1", { tmdbApiKey: null, fetchImpl: fakeFetch([]) })
    ).rejects.toThrow("TMDB_API_KEY");
  });

  it("reads an Open Library work in one search request and its author's QID", async () => {
    const fetchImpl = fakeFetch([
      [/search\.json/, { docs: [OL_KLARA] }],
      [/\/authors\/OL2627906A\.json/, { remote_ids: { wikidata: "Q272076" } }]
    ]);
    const features = await fetchFeatures("book", "openlibrary", "OL20893680W", {
      tmdbApiKey: null,
      fetchImpl
    });
    expect(features.people[0].ids).toEqual({ openlibrary: "OL2627906A", wikidata: "Q272076" });
    expect(String(fetchImpl.mock.calls[0][0])).toContain(
      encodeURIComponent("key:/works/OL20893680W")
    );
  });

  it("uses the earliest official MusicBrainz release, with a User-Agent and a pause before each call", async () => {
    const fetchImpl = fakeFetch([
      [/release-group\//, MB_BLUE_GROUP],
      [/\/release\/rel-first\?/, MB_BLUE_RELEASE],
      [
        /\/artist\//,
        {
          relations: [
            { type: "wikidata", url: { resource: "https://www.wikidata.org/wiki/Q205721" } }
          ]
        }
      ]
    ]);
    const sleep = vi.fn(noSleep);
    const features = await fetchFeatures("album", "musicbrainz", MB_BLUE_GROUP.id, {
      tmdbApiKey: null,
      fetchImpl,
      sleep
    });

    expect(features.lengthRaw).toBe(42.2);
    expect(features.people[0].ids.wikidata).toBe("Q205721");
    expect(sleep).toHaveBeenCalledTimes(3);
    for (const [, init] of fetchImpl.mock.calls) {
      expect((init as RequestInit).headers).toMatchObject({
        "User-Agent": expect.stringContaining("Venn")
      });
    }
  });

  it("keeps the catalog id when a QID lookup fails", async () => {
    const fetchImpl = fakeFetch([[/search\.json/, { docs: [OL_KLARA] }]]);
    const features = await fetchFeatures("book", "openlibrary", "OL20893680W", {
      tmdbApiKey: null,
      fetchImpl
    });
    expect(features.people[0].ids).toEqual({ openlibrary: "OL2627906A" });
  });

  it("refuses a source and kind it has no extractor for", async () => {
    await expect(
      fetchFeatures("book", "tmdb", "1", { tmdbApiKey: "k", fetchImpl: fakeFetch([]) })
    ).rejects.toThrow("no extractor");
  });
});
