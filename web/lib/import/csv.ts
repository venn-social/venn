/**
 * RFC 4180 CSV parsing for the library exports people bring from other apps.
 *
 * Hand-rolled rather than a dependency because the format is small and the
 * edge cases that matter are known: quoted fields holding commas, doubled
 * quotes, and newlines (Letterboxd review text and Goodreads shelves both
 * produce them), CRLF line endings, and a UTF-8 byte-order mark from
 * spreadsheet round-trips. Mirrors ios/Venn/Features/Import/CSV.swift.
 */
export function parseCSV(text: string): string[][] {
  const input = text.startsWith("﻿") ? text.slice(1) : text;
  const rows: string[][] = [];
  let row: string[] = [];
  let field = "";
  let inQuotes = false;

  for (let i = 0; i < input.length; i += 1) {
    const char = input[i];
    if (inQuotes) {
      if (char === '"') {
        if (input[i + 1] === '"') {
          field += '"';
          i += 1;
        } else {
          inQuotes = false;
        }
      } else {
        field += char;
      }
    } else if (char === '"') {
      inQuotes = true;
    } else if (char === ",") {
      row.push(field);
      field = "";
    } else if (char === "\n" || char === "\r") {
      if (char === "\r" && input[i + 1] === "\n") i += 1;
      row.push(field);
      rows.push(row);
      row = [];
      field = "";
    } else {
      field += char;
    }
  }

  if (field !== "" || row.length > 0) {
    row.push(field);
    rows.push(row);
  }
  return rows.filter((cells) => cells.some((cell) => cell.trim() !== ""));
}

/**
 * Rows keyed by the header line. Header names are trimmed; cells keep their
 * text as written. A row shorter than the header simply lacks the missing
 * keys, so a malformed line degrades to "missing field" rather than a throw.
 */
export function csvRecords(text: string): Record<string, string>[] {
  const [header, ...rows] = parseCSV(text);
  if (!header) return [];
  const names = header.map((name) => name.trim());
  return rows.map((cells) => {
    const record: Record<string, string> = {};
    names.forEach((name, index) => {
      if (index < cells.length) record[name] = cells[index];
    });
    return record;
  });
}
