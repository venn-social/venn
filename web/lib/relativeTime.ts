/**
 * Ports RelativeTime.short(from:now:) from ios/Venn/Utils/RelativeTime.swift
 * — same thresholds, same terse labels ("now", "5m", "2h", "3d", "2w").
 * Deliberately no "ago" suffix: these sit in a dense feed row and need to
 * stay quiet. `now` is injectable so formatting is deterministic in tests.
 */
const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const WEEK = 7 * DAY;

export function shortRelativeTime(date: Date, now: Date = new Date()): string {
  // Clamped at zero: clock skew between Postgres and the browser can put a
  // just-created post slightly in the future, and "-1m" reads as a bug.
  const elapsed = Math.max(0, now.getTime() - date.getTime());

  if (elapsed < MINUTE) return "now";
  if (elapsed < HOUR) return `${Math.floor(elapsed / MINUTE)}m`;
  if (elapsed < DAY) return `${Math.floor(elapsed / HOUR)}h`;
  if (elapsed < WEEK) return `${Math.floor(elapsed / DAY)}d`;
  return `${Math.floor(elapsed / WEEK)}w`;
}
