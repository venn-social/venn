import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

/** Mirrors `public.media_kind` and ios/Venn/Models/Media.swift's MediaKind. */
export type MediaKind = "movie" | "show" | "book" | "album";
/** Mirrors `public.post_action` and ios/Venn/Models/Post.swift's PostAction. */
export type PostAction = "logged" | "rated" | "saved";

const MEDIA_KINDS: readonly string[] = ["movie", "show", "book", "album"];
const POST_ACTIONS: readonly string[] = ["logged", "rated", "saved"];

export const FEED_PAGE_SIZE = 20;

export interface FeedMedia {
  id: string;
  kind: MediaKind;
  title: string;
  year: number | null;
  primaryCreator: string | null;
  coverUrl: string | null;
}

export interface FeedPost {
  id: string;
  action: PostAction;
  rating: number | null;
  caption: string | null;
  createdAt: Date;
  media: FeedMedia;
  author: UserProfile;
}

export interface FeedMediaRow {
  id: string;
  kind: MediaKind;
  title: string;
  year: number | null;
  primary_creator: string | null;
  cover_url: string | null;
}

export interface FeedPostRow {
  id: string;
  author_id: string;
  media_id: string;
  action: PostAction;
  rating: number | null;
  caption: string | null;
  created_at: string;
  media: FeedMediaRow;
  author: ProfileRow;
}

/**
 * Lifts a joined wire row into the domain shape. Returns null when `action`
 * or the media `kind` holds a value this client doesn't know — mirroring
 * iOS's `compactMap(FeedPost.init(row:))`. That is what keeps an
 * already-deployed client working when a new media kind ships server-side
 * ahead of a client release: unknown items disappear instead of breaking
 * the whole feed.
 */
export function toFeedPost(row: FeedPostRow): FeedPost | null {
  if (!POST_ACTIONS.includes(row.action)) return null;
  if (!row.media || !MEDIA_KINDS.includes(row.media.kind)) return null;

  return {
    id: row.id,
    action: row.action,
    rating: row.rating,
    caption: row.caption,
    createdAt: new Date(row.created_at),
    media: {
      id: row.media.id,
      kind: row.media.kind,
      title: row.media.title,
      year: row.media.year,
      primaryCreator: row.media.primary_creator,
      coverUrl: row.media.cover_url,
    },
    author: toUserProfile(row.author),
  };
}

/**
 * Serializes the keyset cursor. The fractional seconds are load-bearing:
 * without them every post created in the same second as the cursor is
 * skipped on the following page. Same reasoning as FeedService.cursor(_:).
 */
export function feedCursor(date: Date): string {
  return date.toISOString();
}

/**
 * Recent posts from the people the viewer follows, plus their own, newest
 * first. Mirrors `FeedService.recentPosts(limit:before:)`.
 *
 * Pagination is keyset-on-created_at rather than an offset: an offset
 * silently duplicates rows when new posts land between page fetches.
 *
 * The two round trips (graph, then posts) match iOS, including its known
 * limit — the `in (…)` list bloats the URL past a few hundred follows
 * (docs/TECH_DEBT.md row 5). Keeping the same shape means one future RPC
 * fixes both clients.
 *
 * iOS's no-session fallback to a global feed is deliberately not ported:
 * it exists for previews and the DEBUG boot, and every web page already
 * requires auth.
 */
export async function fetchFeedPage(
  client: SupabaseClient,
  options: { limit?: number; before?: Date } = {}
): Promise<FeedPost[]> {
  const limit = options.limit ?? FEED_PAGE_SIZE;

  const {
    data: { user },
  } = await client.auth.getUser();
  if (!user) return [];

  const { data: follows, error: followsError } = await client
    .from("follows")
    .select("followee_id")
    .eq("follower_id", user.id)
    .eq("status", "accepted");
  if (followsError) throw followsError;

  const authorIds = [...(follows ?? []).map((row) => row.followee_id as string), user.id];

  let query = client
    .from("posts")
    .select("*, media(*), author:profiles(*)")
    .in("author_id", authorIds);

  if (options.before) {
    query = query.lt("created_at", feedCursor(options.before));
  }

  const { data, error } = await query.order("created_at", { ascending: false }).limit(limit);
  if (error) throw error;

  return ((data ?? []) as FeedPostRow[])
    .map(toFeedPost)
    .filter((post): post is FeedPost => post !== null);
}
