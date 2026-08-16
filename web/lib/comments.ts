import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

export interface PostComment {
  id: string;
  body: string;
  createdAt: Date;
  /** Null until the text is changed. Set by the database, never the client. */
  editedAt: Date | null;
  /** Null on a root comment. Replies are one level deep, enforced in the DB. */
  parentId: string | null;
  author: UserProfile;
}

/** A root comment with its replies, oldest first — how a thread reads. */
export interface CommentThreadItem {
  comment: PostComment;
  replies: PostComment[];
}

export interface CommentRow {
  id: string;
  body: string;
  created_at: string;
  edited_at?: string | null;
  parent_id?: string | null;
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
    editedAt: row.edited_at ? new Date(row.edited_at) : null,
    parentId: row.parent_id ?? null,
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
    .select("id, body, created_at, edited_at, parent_id, author:profiles(*)")
    .eq("post_id", postId)
    .order("created_at", { ascending: true })
    .limit(limit);

  if (error) throw error;
  return toComments(data);
}

/**
 * Group a flat fetch into threads.
 *
 * Pure, and no recursion: replies are one level deep by database constraint,
 * so a root and its replies is the whole shape. A reply whose parent is not
 * in the list is promoted to a root rather than dropped — that happens when
 * a thread is paginated, and losing someone's words is worse than showing
 * them slightly out of place.
 */
export function toThreads(comments: PostComment[]): CommentThreadItem[] {
  const roots = comments.filter((comment) => comment.parentId === null);
  const rootIds = new Set(roots.map((root) => root.id));

  const orphans = comments.filter(
    (comment) => comment.parentId !== null && !rootIds.has(comment.parentId)
  );

  return [...roots, ...orphans]
    .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
    .map((comment) => ({
      comment,
      replies: comments
        .filter((reply) => reply.parentId === comment.id)
        .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime())
    }));
}

export async function addComment(
  client: SupabaseClient,
  postId: string,
  authorId: string,
  body: string,
  /** Null for a root comment. The database refuses a reply to a reply. */
  parentId: string | null = null
): Promise<void> {
  const { error } = await client
    .from("post_comments")
    .insert({ post_id: postId, author_id: authorId, body, parent_id: parentId });
  if (error) throw error;
}

/**
 * Deletable by the comment's author or the post's author — the policy
 * enforces it, so this just issues the delete and lets RLS decide.
 */
/**
 * Change the text of a comment you wrote.
 *
 * Only the body is sent. The database pins the post, the author and the
 * original timestamp, and stamps `edited_at` itself — so an edit cannot be
 * made silent, and cannot move a comment somewhere it was never written.
 */
export async function editComment(
  client: SupabaseClient,
  commentId: string,
  body: string
): Promise<void> {
  const { error } = await client.from("post_comments").update({ body }).eq("id", commentId);
  if (error) throw error;
}

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
