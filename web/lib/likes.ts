import type { SupabaseClient } from "@supabase/supabase-js";

/** Like count for one post, plus whether the signed-in viewer liked it. */
export interface LikeInfo {
  likeCount: number;
  likedByMe: boolean;
}

interface LikeInfoRow {
  post_id?: string;
  like_count?: number | string;
  liked_by_me?: boolean;
}

/**
 * Maps the post_like_info rows into a lookup keyed by post id.
 *
 * Postgres `count()` is bigint, which PostgREST serialises as a string, so
 * the count is coerced rather than trusted to be a number.
 */
export function toLikeInfoMap(rows: unknown): Record<string, LikeInfo> {
  if (!Array.isArray(rows)) return {};

  const map: Record<string, LikeInfo> = {};
  for (const row of rows as LikeInfoRow[]) {
    if (!row.post_id) continue;
    map[row.post_id] = {
      likeCount: Number(row.like_count ?? 0),
      likedByMe: row.liked_by_me === true
    };
  }
  return map;
}

/** Every post gets an entry, so callers never branch on "not fetched yet". */
export function withDefaults(
  postIds: string[],
  map: Record<string, LikeInfo>
): Record<string, LikeInfo> {
  const complete: Record<string, LikeInfo> = {};
  for (const id of postIds) {
    complete[id] = map[id] ?? { likeCount: 0, likedByMe: false };
  }
  return complete;
}

/**
 * Like info for many posts in one call. A feed of 20 posts would otherwise
 * be 40 round trips; this is one.
 */
export async function fetchLikeInfo(
  client: SupabaseClient,
  postIds: string[]
): Promise<Record<string, LikeInfo>> {
  if (postIds.length === 0) return {};

  const { data, error } = await client.rpc("post_like_info", { post_ids: postIds });
  if (error) throw error;
  return withDefaults(postIds, toLikeInfoMap(data));
}

/**
 * Idempotent by construction: (post_id, user_id) is the primary key, so
 * liking twice is one row. `ignoreDuplicates` turns the conflict into a
 * no-op rather than an error the UI would have to interpret.
 */
export async function likePost(
  client: SupabaseClient,
  postId: string,
  userId: string
): Promise<void> {
  const { error } = await client
    .from("post_likes")
    .upsert({ post_id: postId, user_id: userId }, { ignoreDuplicates: true });
  if (error) throw error;
}

export async function unlikePost(
  client: SupabaseClient,
  postId: string,
  userId: string
): Promise<void> {
  const { error } = await client
    .from("post_likes")
    .delete()
    .eq("post_id", postId)
    .eq("user_id", userId);
  if (error) throw error;
}
