import type { SupabaseClient } from "@supabase/supabase-js";
import { MEDIA_KINDS, type MediaKind } from "@/lib/media";

/** Mirrors KindStats in YearInReviewService.swift. */
export interface KindStats {
  kind: MediaKind;
  consumedCount: number;
  savedCount: number;
  ratedCount: number;
  /** Null when nothing of this kind has been rated. */
  avgRating: number | null;
  topCreator: string | null;
  topCreatorCount: number | null;
}

/** Mirrors MonthlyStat. `month` stays the raw "YYYY-MM-DD" the RPC returns. */
export interface MonthlyStat {
  month: string;
  count: number;
}

interface KindStatsRow {
  kind?: string;
  consumed_count?: number;
  saved_count?: number;
  rated_count?: number;
  avg_rating?: number | string | null;
  top_creator?: string | null;
  top_creator_count?: number | null;
}

export function toKindStats(rows: unknown): KindStats[] {
  if (!Array.isArray(rows)) return [];

  return (rows as KindStatsRow[])
    .filter((row): row is KindStatsRow & { kind: string } =>
      Boolean(row.kind && MEDIA_KINDS.includes(row.kind))
    )
    .map((row) => ({
      kind: row.kind as MediaKind,
      consumedCount: row.consumed_count ?? 0,
      savedCount: row.saved_count ?? 0,
      ratedCount: row.rated_count ?? 0,
      // Postgres numeric arrives as a string over PostgREST.
      avgRating:
        row.avg_rating === null || row.avg_rating === undefined ? null : Number(row.avg_rating),
      topCreator: row.top_creator ?? null,
      topCreatorCount: row.top_creator_count ?? null
    }));
}

export function toMonthlyStats(rows: unknown): MonthlyStat[] {
  if (!Array.isArray(rows)) return [];
  return (rows as { month?: string; count?: number }[])
    .filter((row): row is { month: string; count?: number } => Boolean(row.month))
    // A missing count is a zero month, not a month to drop — a gap in the
    // axis would misrepresent the year.
    .map((row) => ({ month: row.month, count: row.count ?? 0 }));
}

/** Mirrors YearInReviewSummary.totalConsumed. */
export function totalConsumed(kinds: KindStats[]): number {
  return kinds.reduce((sum, kind) => sum + kind.consumedCount, 0);
}

/**
 * Bar height as a fraction of the busiest month. Zero when nothing was
 * logged all year, which is also what guards the divide by zero.
 */
export function barRatio(count: number, max: number): number {
  if (max <= 0) return 0;
  return count / max;
}

/** "2026-08-01" → "Aug". Returns the input unchanged if it won't parse. */
export function monthLabel(month: string): string {
  const date = new Date(`${month}T00:00:00Z`);
  if (Number.isNaN(date.getTime())) return month;
  return date.toLocaleString("en-US", { month: "short", timeZone: "UTC" });
}

/**
 * Both stats RPCs, in parallel. Each resolves the viewer from auth.uid()
 * internally, so there is no user argument — and no way to ask for someone
 * else's stats.
 */
export async function fetchYearInReview(
  client: SupabaseClient
): Promise<{ kinds: KindStats[]; monthly: MonthlyStat[] }> {
  const [byKind, monthly] = await Promise.all([
    client.rpc("personal_stats_by_kind"),
    client.rpc("personal_stats_monthly")
  ]);

  if (byKind.error) throw byKind.error;
  if (monthly.error) throw monthly.error;

  return { kinds: toKindStats(byKind.data), monthly: toMonthlyStats(monthly.data) };
}
