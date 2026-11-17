import { describe, expect, it, vi } from "vitest";
import { candidateId, type MediaCandidate } from "@/lib/catalog/types";
import {
  MATCH_BATCH,
  runImport,
  toImportItem,
  WRITE_BATCH,
  type ImportItem
} from "@/lib/import/importer";
import type { ImportEntry } from "@/lib/import/types";

function entry(title: string, overrides: Partial<ImportEntry> = {}): ImportEntry {
  return {
    kind: "movie",
    title,
    year: 2000,
    creator: null,
    isbn: null,
    action: "logged",
    rating: null,
    consumedAt: "2020-01-01",
    ...overrides
  };
}

function candidate(id: string): MediaCandidate {
  return {
    id: candidateId("tmdb", "movie", id),
    title: `Film ${id}`,
    year: 2000,
    primaryCreator: null,
    coverUrl: "https://image.tmdb.org/t/p/w500/x.jpg",
    overview: null,
    externalId: id,
    externalSource: "tmdb",
    kind: "movie"
  };
}

/** A fake server with import_library's semantics: one row per external id. */
function fakeServer() {
  const library = new Set<string>();
  const write = vi.fn(async (items: ImportItem[]) => {
    let imported = 0;
    for (const item of items) {
      if (library.has(item.external_id)) continue;
      library.add(item.external_id);
      imported += 1;
    }
    return { imported, skipped: items.length - imported };
  });
  return { library, write };
}

describe("runImport", () => {
  it("writes matches, reports the unmatched, and passes row problems through", async () => {
    const server = fakeServer();
    const problems = [{ file: "watched.csv", line: 4, reason: "missingTitle" as const }];
    const report = await runImport(
      { entries: [entry("A"), entry("Nope"), entry("B")], problems },
      {
        match: async (batch) => batch.map((e) => (e.title === "Nope" ? null : candidate(e.title))),
        write: server.write
      }
    );
    expect(report).toEqual({
      imported: 2,
      alreadyInLibrary: 0,
      unmatched: [entry("Nope")],
      problems
    });
  });

  it("is idempotent: a second run imports nothing new", async () => {
    const server = fakeServer();
    const parsed = { entries: [entry("A"), entry("B")], problems: [] };
    const deps = {
      match: async (b: ImportEntry[]) => b.map((e) => candidate(e.title)),
      write: server.write
    };
    await runImport(parsed, deps);
    const second = await runImport(parsed, deps);
    expect(second.imported).toBe(0);
    expect(second.alreadyInLibrary).toBe(2);
    expect(server.library.size).toBe(2);
  });

  it("collapses rows matching the same item, keeping the most informative", async () => {
    const server = fakeServer();
    const report = await runImport(
      {
        entries: [
          entry("X", { action: "saved" }),
          entry("X again", { action: "rated", rating: 5 })
        ],
        problems: []
      },
      { match: async (b) => b.map(() => candidate("same")), write: server.write }
    );
    expect(server.write).toHaveBeenCalledTimes(1);
    expect(server.write.mock.calls[0][0]).toEqual([
      expect.objectContaining({ action: "rated", rating: 5 })
    ]);
    expect(report).toMatchObject({ imported: 1, alreadyInLibrary: 1 });
  });

  it("batches matching and writing within the server's limits", async () => {
    const server = fakeServer();
    const entries = Array.from({ length: 450 }, (_, i) => entry(String(i)));
    const match = vi.fn(async (b: ImportEntry[]) => b.map((e) => candidate(e.title)));
    const progress = vi.fn();
    const report = await runImport(
      { entries, problems: [] },
      { match, write: server.write, onProgress: progress }
    );

    expect(match).toHaveBeenCalledTimes(Math.ceil(450 / MATCH_BATCH));
    expect(match.mock.calls.every(([b]) => b.length <= MATCH_BATCH)).toBe(true);
    expect(server.write).toHaveBeenCalledTimes(Math.ceil(450 / WRITE_BATCH));
    expect(server.write.mock.calls.every(([b]) => b.length <= WRITE_BATCH)).toBe(true);
    expect(progress).toHaveBeenLastCalledWith(450, 450);
    expect(report.imported).toBe(450);
  });

  it("writes nothing when matching fails part-way", async () => {
    const server = fakeServer();
    const entries = Array.from({ length: MATCH_BATCH + 1 }, (_, i) => entry(String(i)));
    let calls = 0;
    const match = async (b: ImportEntry[]) => {
      calls += 1;
      if (calls === 2) throw new Error("offline");
      return b.map((e) => candidate(e.title));
    };
    await expect(
      runImport({ entries, problems: [] }, { match, write: server.write })
    ).rejects.toThrow("offline");
    expect(server.write).not.toHaveBeenCalled();
  });
});

describe("toImportItem", () => {
  it("takes catalog fields from the match and the opinion from the export", () => {
    expect(
      toImportItem({
        entry: entry("ignored", { action: "rated", rating: 3 }),
        candidate: candidate("9")
      })
    ).toEqual({
      kind: "movie",
      title: "Film 9",
      year: 2000,
      primary_creator: null,
      cover_url: "https://image.tmdb.org/t/p/w500/x.jpg",
      external_source: "tmdb",
      external_id: "9",
      action: "rated",
      rating: 3,
      consumed_at: "2020-01-01"
    });
  });
});
