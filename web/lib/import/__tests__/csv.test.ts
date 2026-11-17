import { describe, expect, it } from "vitest";
import { csvRecords, parseCSV } from "@/lib/import/csv";

describe("parseCSV", () => {
  it("splits plain rows and fields", () => {
    expect(parseCSV("a,b\n1,2\n")).toEqual([
      ["a", "b"],
      ["1", "2"]
    ]);
  });

  it("keeps commas, doubled quotes and newlines inside quoted fields", () => {
    const text = 'Name,Review\n"Crouching Tiger, Hidden Dragon","He said ""wow""\nthen left"\n';
    expect(parseCSV(text)).toEqual([
      ["Name", "Review"],
      ["Crouching Tiger, Hidden Dragon", 'He said "wow"\nthen left']
    ]);
  });

  it("handles CRLF line endings, a byte-order mark and a missing final newline", () => {
    expect(parseCSV("﻿a,b\r\n1,2")).toEqual([
      ["a", "b"],
      ["1", "2"]
    ]);
  });

  it("keeps empty fields and drops blank lines", () => {
    expect(parseCSV("a,,c\n\n1,,\n")).toEqual([
      ["a", "", "c"],
      ["1", "", ""]
    ]);
  });
});

describe("csvRecords", () => {
  it("keys rows by trimmed header names", () => {
    expect(csvRecords(" Name ,Year\nHeat,1995\n")).toEqual([{ Name: "Heat", Year: "1995" }]);
  });

  it("leaves out keys a short row does not reach", () => {
    expect(csvRecords("Name,Year,Rating\nHeat\n")).toEqual([{ Name: "Heat" }]);
  });

  it("returns nothing for an empty file", () => {
    expect(csvRecords("")).toEqual([]);
  });
});
