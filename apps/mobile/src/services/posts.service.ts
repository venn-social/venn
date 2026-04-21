/**
 * posts.service.ts — post/feed API calls.
 *
 * Keep these functions pure wrappers around Supabase: they take plain params,
 * return plain domain types, and throw on errors. No React, no UI, no state.
 */
import type { Post } from '@/types';

import { supabase } from '@/lib/supabase';

interface PostRow {
  id: string;
  author_id: string;
  caption: string;
  media_url: string | null;
  like_count: number;
  comment_count: number;
  created_at: string;
}

function rowToPost(row: PostRow): Post {
  return {
    id: row.id,
    authorId: row.author_id,
    caption: row.caption,
    mediaUrl: row.media_url,
    likeCount: row.like_count,
    commentCount: row.comment_count,
    createdAt: row.created_at,
  };
}

export async function fetchFeed(limit = 20): Promise<Post[]> {
  const { data, error } = await supabase
    .from('posts')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error(error.message);
  }
  return (data ?? []).map(rowToPost);
}
