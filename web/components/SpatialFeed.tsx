"use client";

import Link from "next/link";
import { StarIcon } from "@/components/Icon";
import { useCallback, useEffect, useRef, useState } from "react";
import { FEED_PAGE_SIZE, fetchFeedPage, type FeedPost } from "@/lib/feed";
import { createClient } from "@/lib/supabase/client";

/**
 * The feed as a plane you wander rather than a column you scroll.
 *
 * Posts are laid out across a very large surface and you move in any
 * direction — up, down, sideways, diagonally — with more appearing wherever
 * you go. Cosmos does this and it suits venn for the same reason: browsing
 * taste is not a queue with a beginning and an end, and a single column
 * quietly insists that it is.
 *
 * How it stays fast, and finite:
 *
 *   - **Only what you can see exists.** The surface is a spacer div of
 *     `PLANE` pixels; the cards inside are absolutely positioned and we
 *     render just the cells intersecting the viewport plus a margin. Panning
 *     across the whole plane never mounts more than a few dozen nodes.
 *   - **Position decides content.** A cell's coordinates map to a post
 *     arithmetically, so the same spot always holds the same thing. Without
 *     that, the plane would reshuffle under you as you moved and going back
 *     the way you came would land somewhere new.
 *   - **The pool grows as you explore.** Panning far enough fetches the next
 *     page and widens the pool, so "more appears" is true rather than the
 *     same twenty posts tiled forever. Once the feed is exhausted it does
 *     tile — which is the honest behaviour for a surface with no edges.
 */

/** Card footprint including its gutter. */
const CELL_W = 190;
const CELL_H = 290;
/** Cells beyond the viewport to keep mounted, so panning reveals no gaps. */
const OVERSCAN = 1;
/** Big enough to feel edgeless; small enough that browsers scroll it happily. */
const PLANE = 120_000;
/** Movement under this is a click that wobbled, not a drag. */
const DRAG_SLOP = 4;
/** How far you must roam before we go looking for more posts. */
const FETCH_EVERY_PX = 2_400;
/**
 * Posts to have in hand before the plane settles.
 *
 * A screen holds roughly thirty cells, and showing thirty different covers
 * needs at least thirty posts. One page is twenty, so the plane fills up
 * front rather than waiting for you to wander into the repeats.
 */
const TARGET_POOL = 60;

interface SpatialFeedProps {
  initialPosts: FeedPost[];
  /** Cursor for the next page — the oldest post the server rendered. */
  initialCursor: string | null;
  initialHasMore: boolean;
}

export function SpatialFeed({ initialPosts, initialCursor, initialHasMore }: SpatialFeedProps) {
  const viewport = useRef<HTMLDivElement>(null);
  const [posts, setPosts] = useState(initialPosts);
  const [view, setView] = useState({ left: 0, top: 0, width: 0, height: 0 });

  const cursor = useRef(initialCursor);
  const hasMore = useRef(initialHasMore);
  const loading = useRef(false);
  const lastFetchAt = useRef({ left: 0, top: 0 });
  const frame = useRef(0);

  /** Read the viewport's real position, at most once per frame. */
  const sync = useCallback(() => {
    if (frame.current) return;
    frame.current = requestAnimationFrame(() => {
      frame.current = 0;
      const element = viewport.current;
      if (!element) return;
      setView({
        left: element.scrollLeft,
        top: element.scrollTop,
        width: element.clientWidth,
        height: element.clientHeight
      });
    });
  }, []);

  const loadMore = useCallback(async () => {
    if (loading.current || !hasMore.current || !cursor.current) return;
    loading.current = true;
    try {
      const next = await fetchFeedPage(createClient(), {
        before: new Date(cursor.current),
        limit: FEED_PAGE_SIZE
      });
      if (next.length < FEED_PAGE_SIZE) hasMore.current = false;
      if (next.length > 0) {
        cursor.current = next[next.length - 1].createdAt.toISOString();
        setPosts((current) => [...current, ...next]);
      }
    } catch {
      // The plane still works with the pool we have; it just repeats
      // sooner. Not worth an error state over.
      hasMore.current = false;
    } finally {
      loading.current = false;
    }
  }, []);

  // Fill the pool before the plane settles, so there are enough distinct
  // covers to fill a screen without repeating one.
  useEffect(() => {
    let cancelled = false;
    async function fill() {
      while (!cancelled && hasMore.current && posts.length < TARGET_POOL) {
        const before = posts.length;
        await loadMore();
        // loadMore is a no-op while one is in flight; without this the
        // loop would spin.
        if (posts.length === before) break;
      }
    }
    void fill();
    return () => {
      cancelled = true;
    };
    // Deliberately mount-only: this is the initial fill, and re-running it
    // as the pool grows is what the distance-based fetch below is for.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Start in the middle, so there is as much plane behind you as ahead.
  useEffect(() => {
    const element = viewport.current;
    if (!element) return;
    const origin = PLANE / 2;
    element.scrollLeft = origin - element.clientWidth / 2;
    element.scrollTop = origin - element.clientHeight / 2;
    lastFetchAt.current = { left: element.scrollLeft, top: element.scrollTop };
    sync();
  }, [sync]);

  // Roaming far enough asks for more posts. Distance rather than an edge,
  // because a plane has no edge to hit.
  useEffect(() => {
    const dx = view.left - lastFetchAt.current.left;
    const dy = view.top - lastFetchAt.current.top;
    if (Math.hypot(dx, dy) < FETCH_EVERY_PX) return;
    lastFetchAt.current = { left: view.left, top: view.top };
    void loadMore();
  }, [view, loadMore]);

  // Drag to pan. Trackpads and touch already scroll in two axes; a mouse
  // does not, and without this the sideways half of the idea is unreachable
  // for anyone using one.
  const drag = useRef<{ x: number; y: number; left: number; top: number } | null>(null);
  const moved = useRef(false);

  function onPointerDown(event: React.PointerEvent<HTMLDivElement>) {
    const element = viewport.current;
    if (!element) return;
    // Deliberately started even on a card. The plane is wall-to-wall
    // covers, so refusing to drag from one — which is what letting links
    // keep their own pointer events amounts to — leaves almost nowhere to
    // grab. A click is told apart from a drag by distance instead, below.
    drag.current = {
      x: event.clientX,
      y: event.clientY,
      left: element.scrollLeft,
      top: element.scrollTop
    };
    moved.current = false;
    // Deliberately *not* capturing the pointer yet. A captured pointer
    // sends its click to the capturing element, so capturing here sent
    // every click to this container instead of the card under it — the
    // covers were unopenable, silently, because the anchor never saw the
    // click at all. Capture happens below, once the gesture is actually a
    // drag and there is no click left to lose.
  }

  function onPointerMove(event: React.PointerEvent<HTMLDivElement>) {
    const start = drag.current;
    const element = viewport.current;
    if (!start || !element) return;

    const dx = event.clientX - start.x;
    const dy = event.clientY - start.y;
    // A few pixels of slack, so a slightly shaky click is still a click.
    if (!moved.current && (Math.abs(dx) > DRAG_SLOP || Math.abs(dy) > DRAG_SLOP)) {
      moved.current = true;
      // Now it is a drag: hold the pointer so leaving the plane, or
      // crossing a card, does not drop it mid-gesture.
      event.currentTarget.setPointerCapture(event.pointerId);
    }

    // Nothing moves until it is a drag. Panning by the two pixels a hand
    // wobbles during a click is invisible, but the scroll it causes makes
    // the browser cancel the click — so the cover would not open and
    // nothing on screen would explain why.
    if (!moved.current) return;

    element.scrollLeft = start.left - dx;
    element.scrollTop = start.top - dy;
    sync();
  }

  function endDrag(event: React.PointerEvent<HTMLDivElement>) {
    if (!drag.current) return;
    drag.current = null;
    if (viewport.current?.hasPointerCapture(event.pointerId)) {
      viewport.current.releasePointerCapture(event.pointerId);
    }
  }

  /** Swallow the click that ends a drag, so panning never opens a title. */
  function onClickCapture(event: React.MouseEvent<HTMLDivElement>) {
    if (!moved.current) return;
    event.preventDefault();
    event.stopPropagation();
    moved.current = false;
  }

  function onKeyDown(event: React.KeyboardEvent<HTMLDivElement>) {
    const element = viewport.current;
    if (!element) return;
    const step = event.shiftKey ? CELL_W * 3 : CELL_W;
    const moves: Record<string, [number, number]> = {
      ArrowLeft: [-step, 0],
      ArrowRight: [step, 0],
      ArrowUp: [0, -step],
      ArrowDown: [0, step]
    };
    const move = moves[event.key];
    if (!move) return;
    event.preventDefault();
    element.scrollBy({ left: move[0], top: move[1], behavior: "smooth" });
    sync();
  }

  const cells = visibleCells(view, posts.length);

  return (
    <div
      ref={viewport}
      onScroll={sync}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={endDrag}
      onClickCapture={onClickCapture}
      onPointerCancel={endDrag}
      onKeyDown={onKeyDown}
      tabIndex={0}
      role="region"
      aria-label="Feed, as a plane you can pan in any direction"
      className="h-[calc(100dvh-3.5rem)] w-full cursor-grab overflow-auto overscroll-contain active:cursor-grabbing [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
    >
      <div className="relative" style={{ width: PLANE, height: PLANE }}>
        {cells.map(({ col, row, index }) => {
          const post = posts[index];
          if (!post) return null;
          return (
            <PlaneCard
              key={`${col}:${row}`}
              post={post}
              x={col * CELL_W}
              y={row * CELL_H + columnOffset(col)}
            />
          );
        })}
      </div>
    </div>
  );
}

function PlaneCard({ post, x, y }: { post: FeedPost; x: number; y: number }) {
  return (
    <div className="absolute p-2" style={{ left: x, top: y, width: CELL_W, height: CELL_H }}>
      <Link
        href={`/media/${post.media.id}`}
        // Dragging from a card must pan, not start a native image drag.
        draggable={false}
        className="group flex h-full flex-col gap-1.5"
      >
        <div className="relative flex flex-1 items-center justify-center overflow-hidden rounded-md bg-(--color-surface-strong) transition-transform duration-200 ease-out group-hover:z-10 motion-safe:group-hover:scale-[1.04]">
          {post.media.coverUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
            <img
              src={post.media.coverUrl}
              alt={post.media.title}
              loading="lazy"
              draggable={false}
              className="h-full w-full object-cover transition-transform duration-300 ease-out motion-safe:group-hover:scale-[1.06]"
            />
          ) : (
            <span className="px-2 text-center text-xs text-(--color-text-secondary)">
              {post.media.title}
            </span>
          )}
        </div>
        <span className="flex items-baseline gap-1.5 text-xs text-(--color-text-secondary)">
          <span className="truncate">{post.author.displayName ?? post.author.username}</span>
          {post.rating !== null && (
            // Same treatment as the column: whose opinion it is and what
            // they thought belong together, and a cover with no verdict
            // beside it is just a picture.
            <span className="ml-auto flex shrink-0 items-center gap-0.5 font-semibold text-(--color-text-primary)">
              <StarIcon size={11} className="text-(--color-accent)" />
              {post.rating.toFixed(1)}
            </span>
          )}
        </span>
      </Link>
    </div>
  );
}

/**
 * A fixed vertical nudge per column, so the plane reads as a drift of
 * covers rather than as a spreadsheet. Derived from the column index, not
 * random, or it would jump every time the column re-entered view.
 */
function columnOffset(col: number): number {
  const wave = Math.sin(col * 1.7) * 0.5 + Math.sin(col * 0.6) * 0.5;
  return Math.round(wave * (CELL_H / 6));
}

/**
 * Which cells are on screen, and what each one holds.
 *
 * The post is chosen from the cell's own coordinates, so a spot's content
 * never changes while you pan.
 *
 * Which post, though, is the whole difficulty. The obvious arithmetic —
 * scatter the pool with a couple of multipliers — puts the same cover on
 * screen twice constantly, because two cells collide whenever their
 * coordinate difference happens to be a multiple of the pool size, and at
 * small pool sizes that is most of them.
 *
 * Instead the pool is laid out as one block, sized so it is wider and
 * taller than the viewport, and that block tiles the plane. A repeat is
 * then always at least one full screen away in both directions: when the
 * pool is big enough to fill a screen, you never see the same artwork
 * twice at once. When it is not, the layout still spaces the repeats as
 * far apart as the pool allows, which is the best available answer.
 */
export function visibleCells(
  view: { left: number; top: number; width: number; height: number },
  poolSize: number
): { col: number; row: number; index: number }[] {
  if (poolSize === 0 || view.width === 0) return [];

  const firstCol = Math.floor(view.left / CELL_W) - OVERSCAN;
  const lastCol = Math.ceil((view.left + view.width) / CELL_W) + OVERSCAN;
  const firstRow = Math.floor(view.top / CELL_H) - OVERSCAN;
  const lastRow = Math.ceil((view.top + view.height) / CELL_H) + OVERSCAN;

  // One larger than what fits in each direction, so a repeat sits off
  // screen rather than at the far edge of it.
  const wanted = {
    w: Math.ceil(view.width / CELL_W) + 2,
    h: Math.ceil(view.height / CELL_H) + 2
  };

  let blockW: number;
  let blockH: number;
  if (wanted.w * wanted.h <= poolSize) {
    // Enough posts to fill a screen with no repeat at all.
    blockW = wanted.w;
    blockH = wanted.h;
  } else {
    // Not enough. Shrink the block keeping the viewport's proportions, so
    // what repeats is as far away as it can be in *both* directions —
    // taking the full width first would make the block one row tall and
    // stack the same cover directly above itself.
    const scale = Math.sqrt(poolSize / (wanted.w * wanted.h));
    blockW = Math.max(1, Math.floor(wanted.w * scale));
    blockH = Math.max(1, Math.floor(poolSize / blockW));
  }

  const cells: { col: number; row: number; index: number }[] = [];
  for (let col = firstCol; col <= lastCol; col += 1) {
    for (let row = firstRow; row <= lastRow; row += 1) {
      const x = ((col % blockW) + blockW) % blockW;
      const y = ((row % blockH) + blockH) % blockH;
      cells.push({ col, row, index: x + y * blockW });
    }
  }
  return cells;
}
