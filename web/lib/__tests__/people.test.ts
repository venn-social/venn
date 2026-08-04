import { describe, expect, it } from "vitest";
import { containsPattern } from "@/lib/people";

describe("containsPattern", () => {
  it("wraps a plain term in contains wildcards", () => {
    expect(containsPattern("ada")).toBe("*ada*");
  });

  it("keeps the username alphabet", () => {
    expect(containsPattern("ada_love-lace9")).toBe("*ada_love-lace9*");
  });

  it("keeps accented letters", () => {
    expect(containsPattern("José")).toBe("*José*");
  });

  it("strips characters PostgREST treats as filter syntax", () => {
    // Commas separate conditions, dots separate column.operator.value,
    // parens group, quotes delimit — any of these would corrupt the
    // or(...) string this feeds into.
    expect(containsPattern("a,b.c(d)e'f\"g")).toBe("*abcdefg*");
  });

  it("strips wildcards so a user can't widen their own match", () => {
    expect(containsPattern("a*b%c")).toBe("*abc*");
  });

  it("collapses internal whitespace and trims the edges", () => {
    expect(containsPattern("  ada   lovelace  ")).toBe("*ada lovelace*");
  });

  it("returns an empty string when nothing searchable survives", () => {
    // The caller must treat this as "no results" and issue no query.
    expect(containsPattern("...")).toBe("");
    expect(containsPattern("")).toBe("");
    expect(containsPattern("   ")).toBe("");
  });
});
