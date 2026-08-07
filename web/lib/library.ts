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

  // Curated first, then everything never placed, newest-first among itself.
  // Matches the index and iOS's ProfileService ordering exactly.
  const { data, error } = await query
    .order("position", { ascending: true, nullsFirst: false })
    .order("created_at", { ascending: false });
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

/**
 * Change the rating on a post you already have.
 *
 * Only touches action and rating — the caption and the media it points at
 * stay as they were. The BEFORE UPDATE trigger moves created_at forward, so
 * a re-rate resurfaces in friends' feeds rather than staying buried at the
 * moment you first logged it.
 */
export async function updatePostRating(
  client: SupabaseClient,
  postId: string,
  options: { action: PostAction; rating: number | null }
): Promise<void> {
  const { error } = await client
    .from("posts")
    .update({ action: options.action, rating: options.rating })
    .eq("id", postId);
  if (error) throw error;
}

/**
 * Put someone else's feed item on your own watchlist.
 *
 * `ignoreDuplicates` matters: posts is unique on (author_id, media_id), so a
 * plain upsert would overwrite a row you already have — quietly demoting a
 * film you rated five stars back to "saved". Doing nothing when a row
 * exists is the only safe behaviour here.
 */
export async function saveToWatchlist(
  client: SupabaseClient,
  options: { authorId: string; mediaId: string }
): Promise<void> {
  const { error } = await client.from("posts").upsert(
    {
      author_id: options.authorId,
      media_id: options.mediaId,
      action: "saved" as PostAction,
      rating: null,
      caption: null
    },
    { onConflict: "author_id,media_id", ignoreDuplicates: true }
  );
  if (error) throw error;
}

/**
 * Log someone else's feed item into your own collection.
 *
 * A plain upsert, unlike `saveToWatchlist`: promoting something you had
 * saved into something you have consumed is the point, so overwriting is
 * correct here.
 */
export async function logFromFeed(
  client: SupabaseClient,
  options: { authorId: string; mediaId: string }
): Promise<void> {
  const { error } = await client.from("posts").upsert(
    {
      author_id: options.authorId,
      media_id: options.mediaId,
      action: "logged" as PostAction,
      rating: null,
      caption: null
    },
    { onConflict: "author_id,media_id" }
  );
  if (error) throw error;
}

/**
 * Rewrite the order of a shelf.
 *
 * Sends every id rather than the moved pair: the RPC applies it in one
 * statement, so a failure cannot leave two covers claiming one slot, and a
 * shelf whose positions have drifted comes back consistent. Same shape as
 * `reorderList`.
 */
export async function reorderLibrary(
  client: SupabaseClient,
  postIds: string[]
): Promise<void> {
  const { error } = await client.rpc("reorder_library_items", { _post_ids: postIds });
  if (error) throw error;
}

/**
 * The order that results from moving `postId` to `toIndex`.
 *
 * Pure, so the rules are testable without a database and the grid can
 * render the new arrangement before the write lands. Returns the input
 * unchanged if either end is out of range.
 */
export function movedLibraryOrder(
  items: LibraryItem[],
  postId: string,
  toIndex: number
): string[] {
  const ids = items.map((item) => item.id);
  const from = ids.indexOf(postId);
  if (from === -1 || toIndex < 0 || toIndex >= ids.length || from === toIndex) return ids;

  const next = [...ids];
  const [moved] = next.splice(from, 1);
  next.splice(toIndex, 0, moved);
  return next;
}
