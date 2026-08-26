import type { SupabaseClient } from "@supabase/supabase-js";
import { ratingToPost } from "@/lib/compose";
import type { PostAction } from "@/lib/feed";
import { toMedia, type Media, type MediaRow } from "@/lib/media";

/**
 * The Hall of Fame: the handful of things that represent you.
 *
 * A profile opens with these rather than the whole collection, because a
 * collection records what you have seen and the hall says what you like.
 * Everything stays in the collection either way — the hall is a flag on a
 * log, not a separate place things move to.
 *
 * Membership and order are one column, `posts.hall_position`: null means
 * not in the hall, 1..12 is the place in the grid. The cap is enforced by
 * the database (a range check plus a unique index per author), so nothing
 * here counts before inserting and two tabs cannot both add a twelfth.
 */
export const HALL_CAPACITY = 12;

/** Where a title already sits for one person, if anywhere. */
export interface MediaStanding {
  postId: string;
  action: PostAction;
  hallPosition: number | null;
}

export interface HallItem {
  postId: string;
  position: number;
  media: Media;
}

interface StandingRow {
  id: string;
  action: PostAction;
  hall_position: number | null;
}

/**
 * What this person has already done with this title.
 *
 * Null means untouched. Everything the media page's three controls show —
 * which is lit, and what tapping another one would displace — comes from
 * this one read.
 */
export async function fetchMediaStanding(
  client: SupabaseClient,
  options: { userId: string; mediaId: string }
): Promise<MediaStanding | null> {
  const { data, error } = await client
    .from("posts")
    .select("id, action, hall_position")
    .eq("author_id", options.userId)
    .eq("media_id", options.mediaId)
    .maybeSingle();

  if (error) throw error;
  if (!data) return null;

  const row = data as StandingRow;
  return { postId: row.id, action: row.action, hallPosition: row.hall_position };
}

/** Someone's hall, in the order they arranged it. */
export async function fetchHall(
  client: SupabaseClient,
  userId: string
): Promise<HallItem[]> {
  const { data, error } = await client
    .from("posts")
    .select("id, hall_position, media(*)")
    .eq("author_id", userId)
    .not("hall_position", "is", null)
    .order("hall_position", { ascending: true });

  if (error) throw error;

  return (data ?? [])
    .map((row) => {
      const typed = row as unknown as { id: string; hall_position: number; media: MediaRow };
      const media = typed.media ? toMedia(typed.media) : null;
      return media ? { postId: typed.id, position: typed.hall_position, media } : null;
    })
    .filter((item): item is HallItem => item !== null);
}

/**
 * The lowest free slot, or null when the hall is full.
 *
 * Lowest rather than highest: leaving the hall frees a slot in the middle,
 * and the next thing added should fill the gap rather than the grid growing
 * a hole nothing can occupy.
 */
export function nextFreeSlot(taken: number[]): number | null {
  for (let slot = 1; slot <= HALL_CAPACITY; slot += 1) {
    if (!taken.includes(slot)) return slot;
  }
  return null;
}

/**
 * Put a title in the hall, logging it as loved on the way in.
 *
 * Adding to your profile is a statement that you love the thing, so it
 * carries the same rating choosing "love" in the composer would. Something
 * already logged keeps its own rating — overwriting a considered rating
 * with an implied one would be worse than leaving it.
 */
export async function addToHall(
  client: SupabaseClient,
  options: { authorId: string; mediaId: string; standing: MediaStanding | null }
): Promise<{ added: boolean; full: boolean }> {
  const { data, error } = await client
    .from("posts")
    .select("hall_position")
    .eq("author_id", options.authorId)
    .not("hall_position", "is", null);
  if (error) throw error;

  const taken = (data ?? []).map((row) => (row as { hall_position: number }).hall_position);
  const slot = nextFreeSlot(taken);
  if (slot === null) return { added: false, full: true };

  const loved = ratingToPost("love");
  const keepsOwnRating = options.standing !== null && options.standing.action === "rated";

  const { error: writeError } = await client.from("posts").upsert(
    {
      author_id: options.authorId,
      media_id: options.mediaId,
      action: keepsOwnRating ? options.standing!.action : loved.action,
      ...(keepsOwnRating ? {} : { rating: loved.rating }),
      hall_position: slot
    },
    { onConflict: "author_id,media_id" }
  );
  if (writeError) throw writeError;

  return { added: true, full: false };
}

/** Take a title out of the hall. The log itself stays. */
export async function removeFromHall(
  client: SupabaseClient,
  options: { authorId: string; mediaId: string }
): Promise<void> {
  const { error } = await client
    .from("posts")
    .update({ hall_position: null })
    .eq("author_id", options.authorId)
    .eq("media_id", options.mediaId);
  if (error) throw error;
}
