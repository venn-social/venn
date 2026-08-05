import type { SupabaseClient } from "@supabase/supabase-js";
import { toMedia, type Media, type MediaRow } from "@/lib/media";

export interface UserList {
  id: string;
  ownerId: string;
  title: string;
  description: string | null;
  isPublic: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface ListItem {
  media: Media;
  position: number;
  note: string | null;
}

interface ListRow {
  id: string;
  owner_id: string;
  title: string;
  description: string | null;
  is_public: boolean;
  created_at: string;
  updated_at: string;
}

export function toList(row: ListRow): UserList {
  return {
    id: row.id,
    ownerId: row.owner_id,
    title: row.title,
    description: row.description,
    isPublic: row.is_public,
    createdAt: new Date(row.created_at),
    updatedAt: new Date(row.updated_at)
  };
}

export function toLists(rows: unknown): UserList[] {
  if (!Array.isArray(rows)) return [];
  return (rows as ListRow[]).filter((row) => Boolean(row?.id)).map(toList);
}

interface ListItemRow {
  position?: number;
  note?: string | null;
  media: MediaRow;
}

export function toListItems(rows: unknown): ListItem[] {
  if (!Array.isArray(rows)) return [];
  return (rows as ListItemRow[])
    .map((row): ListItem | null => {
      const media = toMedia(row.media);
      if (!media) return null;
      return { media, position: row.position ?? 0, note: row.note ?? null };
    })
    .filter((item): item is ListItem => item !== null);
}

/**
 * Lists owned by one person. RLS decides what's visible: a private list
 * only comes back to its owner, so this needs no is_public filter of its
 * own — and adding one would risk it drifting from the policy.
 */
export async function fetchListsFor(
  client: SupabaseClient,
  ownerId: string
): Promise<UserList[]> {
  const { data, error } = await client
    .from("lists")
    .select("*")
    .eq("owner_id", ownerId)
    .order("updated_at", { ascending: false });

  if (error) throw error;
  return toLists(data);
}

/** Null when it doesn't exist or RLS hides it — the page turns that into a 404. */
export async function fetchList(
  client: SupabaseClient,
  listId: string
): Promise<UserList | null> {
  const { data, error } = await client.from("lists").select("*").eq("id", listId).maybeSingle();

  if (error) {
    if (error.code === "22P02") return null; // junk uuid in the URL
    throw error;
  }
  return data ? toList(data as ListRow) : null;
}

/** In the maker's chosen order — the order is the point of a list. */
export async function fetchListItems(
  client: SupabaseClient,
  listId: string
): Promise<ListItem[]> {
  const { data, error } = await client
    .from("list_items")
    .select("position, note, media(*)")
    .eq("list_id", listId)
    .order("position", { ascending: true });

  if (error) throw error;
  return toListItems(data);
}

/**
 * Where the next appended item goes.
 *
 * Derived from the highest existing position rather than the item count:
 * removing an item from the middle leaves a gap, and counting would then
 * hand out a position that's already taken.
 */
export function nextPosition(items: ListItem[]): number {
  return items.reduce((max, item) => Math.max(max, item.position), -1) + 1;
}

export async function createList(
  client: SupabaseClient,
  ownerId: string,
  title: string,
  description: string | null,
  isPublic: boolean
): Promise<string> {
  const { data, error } = await client
    .from("lists")
    .insert({ owner_id: ownerId, title, description, is_public: isPublic })
    .select("id")
    .single();

  if (error) throw error;
  return (data as { id: string }).id;
}

export async function deleteList(client: SupabaseClient, listId: string): Promise<void> {
  const { error } = await client.from("lists").delete().eq("id", listId);
  if (error) throw error;
}

/**
 * Appends to the end of the list. `position` is explicit rather than
 * derived from insertion time because reordering has to be possible later
 * without rewriting timestamps.
 */
export async function addToList(
  client: SupabaseClient,
  listId: string,
  mediaId: string,
  position: number,
  note: string | null = null
): Promise<void> {
  const { error } = await client
    .from("list_items")
    .upsert(
      { list_id: listId, media_id: mediaId, position, note },
      { onConflict: "list_id,media_id" }
    );
  if (error) throw error;
}

export async function removeFromList(
  client: SupabaseClient,
  listId: string,
  mediaId: string
): Promise<void> {
  const { error } = await client
    .from("list_items")
    .delete()
    .eq("list_id", listId)
    .eq("media_id", mediaId);
  if (error) throw error;
}
