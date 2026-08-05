import type { SupabaseClient } from "@supabase/supabase-js";
import { toFeedPost, type FeedPost, type FeedPostRow } from "@/lib/feed";

/**
 * One post by id, with its media and author — the same joined shape the
 * feed uses, so a post detail page and a feed row render from one type.
 *
 * Returns null when the post doesn't exist (or RLS hides it), which the
 * page turns into a 404 rather than an error.
 */
export async function fetchPost(
  client: SupabaseClient,
  postId: string
): Promise<FeedPost | null> {
  const { data, error } = await client
    .from("posts")
    .select("*, media(*), author:profiles(*)")
    .eq("id", postId)
    .maybeSingle();

  if (error) {
    // 22P02 is Postgres's invalid-uuid-syntax: someone typed a junk id
    // into the URL. That's a 404, not a server error.
    if (error.code === "22P02") return null;
    throw error;
  }
  if (!data) return null;

  return toFeedPost(data as unknown as FeedPostRow);
}
