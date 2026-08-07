"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { FeedRow } from "@/components/FeedRow";
import { FEED_PAGE_SIZE, fetchFeedPage, type FeedPost } from "@/lib/feed";
import { createClient } from "@/lib/supabase/client";

interface FeedPaginationProps {
  /** Signed-in user, so later pages offer the same menu as the first. */
  viewerId?: string | null;
  /** Cursor from the last server-rendered post — where page 2 begins. */
  initialCursor: string;
  /** False when the server's first page came back short (feed exhausted). */
  initialHasMore: boolean;
}

/**
 * Owns pages 2..n. The first page is server-rendered by the feed page
 * itself; this takes over once the sentinel scrolls into view — the web
 * equivalent of iOS's lazy footer `.task` trigger in FeedView.
 */
export function FeedPagination({
  initialCursor,
  initialHasMore,
  viewerId = null
}: FeedPaginationProps) {
  const [posts, setPosts] = useState<FeedPost[]>([]);
  const [cursor, setCursor] = useState(initialCursor);
  const [hasMore, setHasMore] = useState(initialHasMore);
  const [failed, setFailed] = useState(false);
  const loadingRef = useRef(false);
  const sentinelRef = useRef<HTMLDivElement>(null);

  const loadMore = useCallback(async () => {
    // A ref rather than state: the observer can fire again before a state
    // update has rendered, which would fetch the same page twice.
    if (loadingRef.current || !hasMore) return;
    loadingRef.current = true;
    setFailed(false);

    try {
      const next = await fetchFeedPage(createClient(), {
        before: new Date(cursor),
        limit: FEED_PAGE_SIZE,
      });

      // A short page means the feed is exhausted. This counts rows kept
      // after dropping unknown kinds, so a page short only because of
      // drops also ends pagination — the same behaviour as iOS's hasMore,
      // and the alternative (looping for a full page) risks a long stall.
      if (next.length < FEED_PAGE_SIZE) setHasMore(false);
      if (next.length > 0) {
        setPosts((current) => [...current, ...next]);
        setCursor(next[next.length - 1].createdAt.toISOString());
      }
    } catch {
      setFailed(true);
    } finally {
      loadingRef.current = false;
    }
  }, [cursor, hasMore]);

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel || !hasMore) return;

    const observer = new IntersectionObserver((entries) => {
      if (entries[0]?.isIntersecting) void loadMore();
    });
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, [loadMore, hasMore]);

  return (
    <>
      {posts.map((post) => (
        <FeedRow key={post.id} post={post} viewerId={viewerId} />
      ))}

      {failed && (
        <button
          type="button"
          onClick={() => void loadMore()}
          className="self-center text-sm font-semibold text-(--color-accent)"
        >
          Couldn&apos;t load more. Try again
        </button>
      )}

      {hasMore && !failed && <div ref={sentinelRef} className="h-8" aria-hidden="true" />}
    </>
  );
}
