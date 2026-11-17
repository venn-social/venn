import { csvRecords } from "@/lib/import/csv";
import { normalizeTitle } from "@/lib/import/match";
import { parseStars, starsToPost } from "@/lib/import/rating";
import type { ImportEntry, ImportRowProblem, ParsedExport } from "@/lib/import/types";
import { sanitizeSearchQuery } from "@/lib/sanitize";

/** The export files this importer reads; others in the zip are ignored. */
export const LETTERBOXD_FILES = [
  "watched.csv",
  "diary.csv",
  "ratings.csv",
  "watchlist.csv"
] as const;
export type LetterboxdFile = (typeof LETTERBOXD_FILES)[number];

interface FilmState {
  title: string;
  year: number | null;
  watched: boolean;
  /** From ratings.csv — the person's current rating, which wins. */
  currentStars: number | null;
  /** From the newest rated diary entry, used when ratings.csv has none. */
  diaryStars: number | null;
  diaryStarsDate: string;
  watchedDate: string | null;
  saved: boolean;
  savedDate: string | null;
}

/**
 * Turns a Letterboxd export into one entry per film.
 *
 * A film can appear in several files — watched, a few diary entries, a
 * rating, even the watchlist — and venn keeps one row per film, so the
 * files are merged:
 *   - Watched anywhere (watched, diary or ratings) → logged, rated if a
 *     rating exists. Watched beats watchlist.
 *   - Only on the watchlist → saved.
 *   - The rating is ratings.csv's (the current one), falling back to the
 *     newest rated diary entry.
 *   - The date is the newest watched date, or the date it was added to the
 *     watchlist.
 *
 * Films are keyed by normalized title + year rather than the "Letterboxd
 * URI" column, because diary.csv's URI points at the diary entry, not the
 * film, so the same film has different URIs in different files.
 *
 * Mirrors ios/Venn/Features/Import/LetterboxdImport.swift.
 */
export function parseLetterboxdExport(
  files: Partial<Record<LetterboxdFile, string>>
): ParsedExport {
  const films = new Map<string, FilmState>();
  const problems: ImportRowProblem[] = [];

  for (const file of LETTERBOXD_FILES) {
    const text = files[file];
    if (text === undefined) continue;

    csvRecords(text).forEach((record, index) => {
      const line = index + 2;
      const cleaned = sanitizeSearchQuery(record["Name"] ?? "");
      if (!cleaned.valid) {
        problems.push({ file, line, reason: "titleTooLong" });
        return;
      }
      if (!cleaned.value) {
        problems.push({ file, line, reason: "missingTitle" });
        return;
      }

      const year = parseYear(record["Year"]);
      const key = `${normalizeTitle(cleaned.value)}|${year ?? ""}`;
      const film = films.get(key) ?? emptyFilm(cleaned.value, year);
      films.set(key, film);
      applyRow(film, file, record);
    });
  }

  return { entries: [...films.values()].map(toEntry), problems };
}

function emptyFilm(title: string, year: number | null): FilmState {
  return {
    title,
    year,
    watched: false,
    currentStars: null,
    diaryStars: null,
    diaryStarsDate: "",
    watchedDate: null,
    saved: false,
    savedDate: null
  };
}

function applyRow(film: FilmState, file: LetterboxdFile, record: Record<string, string>) {
  const date = parseDate(record["Date"]);
  switch (file) {
    case "watched.csv":
      film.watched = true;
      film.watchedDate = newer(film.watchedDate, date);
      break;
    case "diary.csv": {
      film.watched = true;
      const watchedOn = parseDate(record["Watched Date"]) ?? date;
      film.watchedDate = newer(film.watchedDate, watchedOn);
      const stars = parseStars(record["Rating"]);
      const when = watchedOn ?? "";
      if (stars !== null && when >= film.diaryStarsDate) {
        film.diaryStars = stars;
        film.diaryStarsDate = when;
      }
      break;
    }
    case "ratings.csv": {
      const stars = parseStars(record["Rating"]);
      if (stars !== null) {
        film.watched = true;
        film.currentStars = stars;
        film.watchedDate = newer(film.watchedDate, date);
      }
      break;
    }
    case "watchlist.csv":
      film.saved = true;
      film.savedDate = newer(film.savedDate, date);
      break;
  }
}

function toEntry(film: FilmState): ImportEntry {
  const base = {
    kind: "movie" as const,
    title: film.title,
    year: film.year,
    creator: null,
    isbn: null
  };
  if (film.watched) {
    const { action, rating } = starsToPost(film.currentStars ?? film.diaryStars);
    return { ...base, action, rating, consumedAt: film.watchedDate };
  }
  return { ...base, action: "saved", rating: null, consumedAt: film.savedDate };
}

function parseYear(cell: string | undefined): number | null {
  const value = Number.parseInt((cell ?? "").trim(), 10);
  return Number.isInteger(value) && value >= 1800 && value <= 2200 ? value : null;
}

/** Letterboxd writes dates as "YYYY-MM-DD"; anything else is ignored. */
export function parseDate(cell: string | undefined): string | null {
  const value = (cell ?? "").trim();
  return /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

function newer(current: string | null, candidate: string | null): string | null {
  if (candidate === null) return current;
  if (current === null) return candidate;
  return candidate > current ? candidate : current;
}
