import { describe, expect, it } from "vitest";
import {
  hasIdentity,
  planPerson,
  wikidataQid,
  type ExtractedPerson,
  type PersonRow
} from "@/lib/taste/people";

const row = (overrides: Partial<PersonRow>): PersonRow => ({
  id: "p1",
  wikidata_qid: null,
  tmdb_id: null,
  openlibrary_id: null,
  musicbrainz_id: null,
  display_name: "Someone",
  ...overrides
});

const ishiguro = (ids: ExtractedPerson["ids"]): ExtractedPerson => ({
  name: "Kazuo Ishiguro",
  role: "author",
  billing: null,
  ids
});

describe("wikidataQid", () => {
  it("accepts a bare QID or an entity URL, and nothing else", () => {
    expect(wikidataQid("Q272076")).toBe("Q272076");
    expect(wikidataQid("https://www.wikidata.org/wiki/Q272076")).toBe("Q272076");
    expect(wikidataQid("Q0")).toBeUndefined();
    expect(wikidataQid("")).toBeUndefined();
    expect(wikidataQid(null)).toBeUndefined();
  });
});

describe("planPerson", () => {
  it("inserts someone new", () => {
    const plan = planPerson(ishiguro({ openlibrary: "OL2627906A", wikidata: "Q272076" }), []);
    expect(plan).toEqual({
      action: "insert",
      row: {
        wikidata_qid: "Q272076",
        tmdb_id: null,
        openlibrary_id: "OL2627906A",
        musicbrainz_id: null,
        display_name: "Kazuo Ishiguro"
      }
    });
  });

  it("joins the author of a novel to the same person credited on its film, through the QID", () => {
    const fromTmdb = row({ id: "tmdb-row", wikidata_qid: "Q272076", tmdb_id: "59783" });
    const plan = planPerson(ishiguro({ openlibrary: "OL2627906A", wikidata: "Q272076" }), [
      fromTmdb
    ]);
    expect(plan).toEqual({
      action: "update",
      id: "tmdb-row",
      patch: { openlibrary_id: "OL2627906A" }
    });
  });

  it("fills a missing QID on a catalog-id match", () => {
    const existing = row({ id: "ol-row", openlibrary_id: "OL2627906A" });
    const plan = planPerson(ishiguro({ openlibrary: "OL2627906A", wikidata: "Q272076" }), [
      existing
    ]);
    expect(plan).toEqual({ action: "update", id: "ol-row", patch: { wikidata_qid: "Q272076" } });
  });

  it("keeps a row that already has everything", () => {
    const existing = row({ id: "ol-row", openlibrary_id: "OL2627906A", wikidata_qid: "Q272076" });
    expect(
      planPerson(ishiguro({ openlibrary: "OL2627906A", wikidata: "Q272076" }), [existing])
    ).toEqual({
      action: "keep",
      id: "ol-row"
    });
  });

  it("never merges by name: same name, different ids, is a new person", () => {
    const composer = row({ id: "composer", display_name: "John Williams", tmdb_id: "491" });
    const guitarist: ExtractedPerson = {
      name: "John Williams",
      role: "primary_artist",
      billing: null,
      ids: { musicbrainz: "8b8a38a9-a290-4560-84f6-3d4466e8d791" }
    };
    expect(planPerson(guitarist, [composer]).action).toBe("insert");
  });

  it("refuses to attach to a catalog match that already belongs to a different QID", () => {
    const other = row({ id: "other", tmdb_id: "100", wikidata_qid: "Q1" });
    const plan = planPerson(
      { name: "X", role: "director", billing: null, ids: { tmdb: "100", wikidata: "Q2" } },
      [other]
    );
    expect(plan.action).toBe("insert");
  });

  it("does not claim an id another row already holds", () => {
    const qidRow = row({ id: "qid-row", wikidata_qid: "Q272076" });
    const olRow = row({ id: "ol-row", openlibrary_id: "OL2627906A" });
    const plan = planPerson(ishiguro({ openlibrary: "OL2627906A", wikidata: "Q272076" }), [
      qidRow,
      olRow
    ]);
    expect(plan).toEqual({ action: "keep", id: "qid-row" });
  });
});

describe("hasIdentity", () => {
  it("needs at least one id", () => {
    expect(hasIdentity(ishiguro({}))).toBe(false);
    expect(hasIdentity(ishiguro({ openlibrary: "OL1A" }))).toBe(true);
  });
});
