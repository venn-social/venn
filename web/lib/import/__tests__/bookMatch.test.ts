import { describe, expect, it } from "vitest";
import { candidateId, type MediaCandidate } from "@/lib/catalog/types";
import { bestBookMatch, bookTitleKey } from "@/lib/import/match";
import { matchOne } from "@/lib/import/matchEntries";

function book(id: string, title: string, author: string | null): MediaCandidate {
  return {
    id: candidateId("openlibrary", "book", id),
    title,
    year: null,
    primaryCreator: author,
    coverUrl: null,
    overview: null,
    externalId: id,
    externalSource: "openlibrary",
    kind: "book"
  };
}

describe("bookTitleKey", () => {
  it("drops a Goodreads series suffix and a subtitle", () => {
    expect(bookTitleKey("Catching Fire (The Hunger Games, #2)")).toBe("catching fire");
    expect(bookTitleKey("Sapiens: A Brief History of Humankind")).toBe("sapiens");
    expect(bookTitleKey("The Way of Kings (The Stormlight Archive, #1.5)")).toBe("way of kings");
  });

  it("keeps a parenthetical that is not a series", () => {
    expect(bookTitleKey("Love (in theory)")).toBe("love in theory");
  });
});

describe("bestBookMatch", () => {
  const results = [
    book("W1", "Middlemarch", "Someone Else"),
    book("W2", "Middlemarch: A Study of Provincial Life", "George Eliot")
  ];

  it("requires the author's surname when both sides have one", () => {
    expect(bestBookMatch("Middlemarch", "George Eliot", results)?.externalId).toBe("W2");
  });

  it("matches on title alone when the row has no author", () => {
    expect(bestBookMatch("Middlemarch", null, results)?.externalId).toBe("W1");
  });

  it("refuses a different book", () => {
    expect(bestBookMatch("Daniel Deronda", "George Eliot", results)).toBeNull();
  });
});

describe("matchOne for books", () => {
  const entry = {
    kind: "book" as const,
    title: "The Hunger Games (The Hunger Games, #1)",
    year: 2008,
    creator: "Suzanne Collins",
    isbn: "9780439023481"
  };

  it("trusts an ISBN hit", async () => {
    const queries: string[] = [];
    const match = await matchOne(entry, {
      search: async (_kind, query) => {
        queries.push(query);
        return [book("W9", "Hunger Games", "Suzanne Collins")];
      }
    });
    expect(match?.externalId).toBe("W9");
    expect(queries).toEqual(["isbn:9780439023481"]);
  });

  it("falls back to title and author when the ISBN is unknown", async () => {
    const queries: string[] = [];
    const match = await matchOne(entry, {
      search: async (_kind, query) => {
        queries.push(query);
        return query.startsWith("isbn:") ? [] : [book("W7", "The Hunger Games", "Suzanne Collins")];
      }
    });
    expect(match?.externalId).toBe("W7");
    expect(queries[1]).toBe("The Hunger Games Suzanne Collins");
  });
});
