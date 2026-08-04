import { describe, expect, it } from "vitest";
import { normalise, sanitizeBio, sanitizeDisplayName, sanitizeHandle } from "@/lib/sanitize";

describe("sanitizeHandle", () => {
  it("accepts a valid lowercase handle", () => {
    expect(sanitizeHandle("ada")).toEqual({ valid: true, value: "ada" });
  });

  it("lowercases and trims before validating", () => {
    expect(sanitizeHandle("  Ada_Lovelace  ")).toEqual({ valid: true, value: "ada_lovelace" });
  });

  it("rejects a handle under 3 characters", () => {
    expect(sanitizeHandle("ab")).toEqual({ valid: false, reason: "tooShort" });
  });

  it("rejects a handle over 24 characters", () => {
    expect(sanitizeHandle("a".repeat(25))).toEqual({ valid: false, reason: "tooLong" });
  });

  it("rejects characters outside [a-z0-9_-]", () => {
    expect(sanitizeHandle("ada lovelace")).toEqual({ valid: false, reason: "invalidCharacters" });
  });

  it("accepts underscores and hyphens", () => {
    expect(sanitizeHandle("ada_love-lace")).toEqual({ valid: true, value: "ada_love-lace" });
  });
});

describe("sanitizeDisplayName", () => {
  it("accepts a normal name", () => {
    expect(sanitizeDisplayName("Ada Lovelace")).toEqual({ valid: true, value: "Ada Lovelace" });
  });

  it("rejects an empty (or whitespace-only) name", () => {
    expect(sanitizeDisplayName("   ")).toEqual({ valid: false, reason: "empty" });
  });

  it("rejects a name over 40 characters", () => {
    expect(sanitizeDisplayName("a".repeat(41))).toEqual({ valid: false, reason: "tooLong" });
  });

  it("collapses runs of spaces into one", () => {
    expect(sanitizeDisplayName("Ada    Lovelace")).toEqual({ valid: true, value: "Ada Lovelace" });
  });
});

describe("sanitizeBio", () => {
  it("accepts an empty bio — the column is nullable and a bio is optional", () => {
    expect(sanitizeBio("")).toEqual({ valid: true, value: "" });
  });

  it("accepts a bio at exactly the 160-character limit", () => {
    expect(sanitizeBio("a".repeat(160))).toEqual({ valid: true, value: "a".repeat(160) });
  });

  it("rejects a bio over 160 characters", () => {
    expect(sanitizeBio("a".repeat(161))).toEqual({ valid: false, reason: "tooLong" });
  });

  it("normalises before measuring, so collapsed whitespace can bring it under", () => {
    const spaced = `${"a".repeat(158)}${" ".repeat(10)}b`;
    expect(sanitizeBio(spaced)).toEqual({ valid: true, value: `${"a".repeat(158)} b` });
  });
});

describe("normalise", () => {
  it("strips C0 control characters", () => {
    expect(normalise("a\u0000b")).toBe("ab");
  });

  it("strips zero-width and bidi-override characters", () => {
    expect(normalise("a\u200Bb\u202Ec")).toBe("abc");
  });

  it("collapses runs of spaces into one", () => {
    expect(normalise("a    b")).toBe("a b");
  });

  it("caps runs of 3+ blank lines at 2", () => {
    expect(normalise("a\n\n\n\nb")).toBe("a\n\nb");
  });

  it("trims leading and trailing whitespace", () => {
    expect(normalise("  a b  ")).toBe("a b");
  });
});