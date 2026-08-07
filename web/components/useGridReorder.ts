"use client";

import { useRef, useState } from "react";

/** Movement (px) before a press becomes a drag rather than a tap. */
const DRAG_THRESHOLD = 8;

interface UseGridReorderOptions {
  /** Ids in their current display order. */
  ids: string[];
  /** Off for other people's shelves. */
  enabled: boolean;
  /** Called once, on drop, with the settled order. */
  onCommit: (order: string[]) => void;
}

/**
 * Pointer-driven drag reordering for a grid.
 *
 * Pointer events rather than HTML5 drag-and-drop, because HTML5 DnD does
 * not fire on touch and this is a phone-first product. Rather than adding a
 * drag library for one grid, the whole thing is ~60 lines here.
 *
 * The covers are links, so a press is ambiguous until it moves: nothing
 * happens until the pointer travels `DRAG_THRESHOLD`, and once it has, the
 * click that follows is swallowed so dragging never navigates.
 */
export function useGridReorder({ ids, enabled, onCommit }: UseGridReorderOptions) {
  const [draggingId, setDraggingId] = useState<string | null>(null);
  const [order, setOrder] = useState<string[] | null>(null);
  const start = useRef<{ x: number; y: number } | null>(null);
  const didDrag = useRef(false);

  // While idle the caller's order wins, so newly loaded data is not stale.
  const current = order ?? ids;

  function indexUnder(x: number, y: number): number | null {
    const element = document.elementFromPoint(x, y);
    const cell = element?.closest("[data-reorder-index]");
    if (!cell) return null;
    const index = Number(cell.getAttribute("data-reorder-index"));
    return Number.isNaN(index) ? null : index;
  }

  function handlePointerDown(id: string, event: React.PointerEvent) {
    if (!enabled || event.button !== 0) return;
    start.current = { x: event.clientX, y: event.clientY };
    didDrag.current = false;
    setDraggingId(id);
    setOrder(current);
  }

  function handlePointerMove(event: React.PointerEvent) {
    if (!draggingId || !start.current) return;

    const dx = event.clientX - start.current.x;
    const dy = event.clientY - start.current.y;
    if (!didDrag.current && Math.hypot(dx, dy) < DRAG_THRESHOLD) return;

    if (!didDrag.current) {
      didDrag.current = true;
      // Claim the pointer only once it is really a drag, so a plain tap
      // still reaches the link underneath.
      (event.target as Element).setPointerCapture?.(event.pointerId);
    }

    const target = indexUnder(event.clientX, event.clientY);
    if (target === null) return;

    const working = order ?? current;
    const from = working.indexOf(draggingId);
    if (from === -1 || from === target) return;

    const next = [...working];
    const [moved] = next.splice(from, 1);
    next.splice(target, 0, moved);
    setOrder(next);
  }

  function handlePointerUp() {
    if (!draggingId) return;
    const settled = order;
    const moved = didDrag.current;
    setDraggingId(null);
    start.current = null;

    if (moved && settled) {
      onCommit(settled);
    } else {
      // A tap, not a drag — drop the local copy so the caller's order
      // stays authoritative.
      setOrder(null);
    }
  }

  return {
    /** Ids in the order to render right now. */
    order: current,
    draggingId,
    /** True if the last gesture was a drag, so the click should be ignored. */
    consumedClick: () => didDrag.current,
    handlers: (id: string) => ({
      onPointerDown: (event: React.PointerEvent) => handlePointerDown(id, event),
      onPointerMove: handlePointerMove,
      onPointerUp: handlePointerUp,
      onPointerCancel: handlePointerUp
    })
  };
}
