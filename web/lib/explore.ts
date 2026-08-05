import type { SupabaseClient } from "@supabase/supabase-js";
import { toMedia, type Media, type MediaKind, type MediaRow } from "@/lib/media";

/** Shared decoder — unknown kinds drop out rather than breaking the grid. */
export function toMediaList(rows: unknown): Media[] {
  if (!Array.isArray(rows)) return [];
  return (rows as MediaRow[]).map(toMedia).filter((media): media is Media => media !== null);
}

/**
 * Newest catalog media of one kind. Ports ExplorerService.recentMedia.
 *
 * This is what the browse panel shows. It is deliberately unranked: there
 * is no recommendation score yet, and none can exist until there's a follow
 * graph and interaction history to compute one from. The signature is the
 * shape a scored version would keep, so that becomes an implementation
 * change rather than an API change.
 */
export async function fetchRecentMedia(
  client: SupabaseClient,
  kind: MediaKind,
  limit = 20
): Promise<Media[]> {
  const { data, error } = await client
    .from("media")
    .select("*")
    .eq("kind", kind)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return toMediaList(data);
}
