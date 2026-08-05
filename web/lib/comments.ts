import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

export interface PostComment {
  id: string;
  body: string;
  createdAt: Date;
  author: UserProfile;
}

export interface CommentRow {
  id: string;
  body: string;
  created_at: string;
  author: ProfileRow;
}

export function toComment(row: CommentRow): PostComment | null {
  // The embed can come back null if the author row vanished mid-flight;
  // dropping the comment beats rendering one with no name attached.
  if (!row.author) return null;

  return {
    id: row.id,
    body: row.body,
    createdAt: new Date(row.created_at),
    author: toUserProfile(row.author)
  };
}

export function toComments(rows: unknown): PostComment[] {
  if (!Array.isArray(rows)) return [];
  return (rows as CommentRow[])
    .map(toComment)
    .filter((comment): comment is PostComment => comment !== null);
}

/** Oldest first — a conversation reads top to bottom. */
export async function fetchComments(
  client: SupabaseClient,
  postId: string,
  limit = 100
): Promise<PostComment[]> {
  const { data, error } = await client
    .from("post_comments")
    .select("id, body, created_at, author:profiles(*)")
    .eq("post_id", postId)
    .order("created_at", { ascending: true })
    .limit(limit);

  if (error) throw error;
  return toComments(data);
}

export async function addComment(
  client: SupabaseClient,
  postId: string,
  authorId: string,
  body: string
): Promise<void> {
  const { error } = await client
    .from("post_comments")
    .insert({ post_id: postId, author_id: authorId, body });
  if (error) throw error;
}

/**
 * Deletable by the comment's author or the post's author — the policy
 * enforces it, so this just issues the delete and lets RLS decide.
 */
export async function deleteComment(client: SupabaseClient, commentId: string): Promise<void> {
  const { error } = await client.from("post_comments").delete().eq("id", commentId);
  if (error) throw error;
}

interface CommentCountRow {
  post_id?: string;
  comment_count?: number | string;
}

/** Counts for many posts at once — one call per feed page, not per row. */
export function toCommentCounts(rows: unknown): Record<string, number> {
  if (!Array.isArray(rows)) return {};
  const map: Record<string, number> = {};
  for (const row of rows as CommentCountRow[]) {
    if (!row.post_id) continue;
    // bigint arrives as a string over PostgREST.
    map[row.post_id] = Number(row.comment_count ?? 0);
  }
  return map;
}

export async function fetchCommentCounts(
  client: SupabaseClient,
  postIds: string[]
): Promise<Record<string, number>> {
  if (postIds.length === 0) return {};

  const { data, error } = await client.rpc("post_comment_counts", { post_ids: postIds });
  if (error) throw error;

  const counts = toCommentCounts(data);
  const complete: Record<string, number> = {};
  for (const id of postIds) complete[id] = counts[id] ?? 0;
  return complete;
}
