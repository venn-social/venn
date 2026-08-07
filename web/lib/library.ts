import type { SupabaseClient } from "@supabase/supabase-js";
import { toMedia, type Media, type MediaKind, type MediaRow } from "@/lib/media";
import type { PostAction } from "@/lib/feed";

/**
 * A post joined with its media — the building block for both the watchlist
 * (`saved`) and the collection (`logged` / `rated`). Ports
 * ios/Venn/Models/LibraryItem.swift and the queries behind
 * ProfileService.watchlist(for:kind:) / collection(for:kind:).
 */
export interface LibraryItem {
  id: string;
  action: PostAction;
  rating: number | null;
  createdAt: Date;
  media: Media;
}

export interface LibraryItemRow {
  id: string;
  action: PostAction;
  rating: number | null;
  created_at: string;
  media: MediaRow;
}

/** Things the user has consumed. Mirrors ProfileService.collection. */
export const COLLECTION_ACTIONS: readonly PostAction[] = ["logged", "rated"];
/** Things the user intends to consume. Mirrors ProfileService.watchlist. */
export const WATCHLIST_ACTIONS: readonly PostAction[] = ["saved"];

export function toLibraryItem(row: LibraryItemRow): LibraryItem | null {
  const media = toMedia(row.media);
  if (!media) return null;

  return {
    id: row.id,
    action: row.action,
    rating: row.rating,
    createdAt: new Date(row.created_at),
    media,
  };
}

/**
 * The author's posts with the given actions, joined with media, newest
 * first, optionally scoped to one kind.
 *
 * `media!inner` makes the join inner, so filtering the embedded
 * `media.kind` restricts the parent rows — that's what lets the kind filter
 * run server-side instead of fetching every kind and discarding most of it
 * in the client (the fix recorded as tech-debt row 2 on iOS).
 */
async function libraryItems(
  client: SupabaseClient,
  userId: string,
  actions: readonly PostAction[],
  kind?: MediaKind
): Promise<LibraryItem[]> {
  let query = client
    .from("posts")
    .select("id, action, rating, created_at, media!inner(*)")
    .eq("author_id", userId)
    .in("action", actions as PostAction[]);

  if (kind) {
    query = query.eq("media.kind", kind);
  }

  const { data, error } = await query.order("created_at", { ascending: false });
  if (error) throw error;

  return ((data ?? []) as unknown as LibraryItemRow[])
    .map(toLibraryItem)
    .filter((item): item is LibraryItem => item !== null);
}

export function fetchCollection(
  client: SupabaseClient,
  userId: string,
  kind?: MediaKind
): Promise<LibraryItem[]> {
  return libraryItems(client, userId, COLLECTION_ACTIONS, kind);
}

export function fetchWatchlist(
  client: SupabaseClient,
  userId: string,
  kind?: MediaKind
): Promise<LibraryItem[]> {
  return libraryItems(client, userId, WATCHLIST_ACTIONS, kind);
}

/**
 * Delete one of your own posts, removing the item from the shelf it sits on.
 *
 * Ports ProfileService.removeFromLibrary. RLS refuses a delete that is not
 * the author's, so this is safe to call optimistically; the app only ever
 * surfaces the control on your own profile.
 */
export async function removeFromLibrary(
  client: SupabaseClient,
  postId: string
): Promise<void> {
  const { error } = await client.from("posts").delete().eq("id", postId);
  if (error) throw error;
}
