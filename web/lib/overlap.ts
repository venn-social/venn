import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Mirrors ios/Venn/Features/Profile/OverlapService.swift and
 * ios/Venn/Models/Media.swift's MediaKind.
 */
export type MediaKind = "movie" | "show" | "book" | "album";

export interface KindOverlap {
  kind: MediaKind;
  viewerCount: number;
  otherCount: number;
  sharedCount: number;
}

export interface OverlapSummary {
  kinds: KindOverlap[];
  viewerTotal: number;
  otherTotal: number;
  sharedTotal: number;
}

interface KindOverlapRow {
  kind: MediaKind;
  viewer_count: number;
  other_count: number;
  shared_count: number;
}

/** Pure aggregation — mirrors OverlapSummary's init(kinds:). */
export function summarize(kinds: KindOverlap[]): OverlapSummary {
  return {
    kinds,
    viewerTotal: kinds.reduce((sum, k) => sum + k.viewerCount, 0),
    otherTotal: kinds.reduce((sum, k) => sum + k.otherCount, 0),
    sharedTotal: kinds.reduce((sum, k) => sum + k.sharedCount, 0)
  };
}

/**
 * Jaccard similarity (|A ∩ B| / |A ∪ B|) as a 0-100 integer. Ports
 * TasteMatch.percent — null (not 0) when the union is empty, so callers
 * can distinguish "no data yet" from a real 0% match.
 */
export function tasteMatchPercent(shared: number, viewer: number, other: number): number | null {
  const union = viewer + other - shared;
  if (union <= 0) return null;
  return Math.round((shared / union) * 100);
}

/** Mirrors OverlapService.overlap(with:) — same compute_overlap RPC. */
export async function fetchOverlap(
  client: SupabaseClient,
  otherUserId: string
): Promise<OverlapSummary> {
  const { data, error } = await client.rpc("compute_overlap", { other_user: otherUserId });
  if (error) throw error;

  const kinds: KindOverlap[] = (data as KindOverlapRow[]).map((row) => ({
    kind: row.kind,
    viewerCount: row.viewer_count,
    otherCount: row.other_count,
    sharedCount: row.shared_count
  }));
  return summarize(kinds);
}
