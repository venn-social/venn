"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { ChevronLeftIcon, ChevronRightIcon } from "@/components/Icon";

interface ScrollRowProps {
  children: React.ReactNode;
  /** Announced on the arrows, e.g. "More like Her". */
  label: string;
}

/**
 * A horizontal row you page through with arrows rather than a scrollbar.
 *
 * The shelves used to expose a native horizontal scrollbar, which on most
 * desktop setups is a grey bar sitting under the covers doing nothing for
 * the design and, on a mouse without horizontal scroll, not much for the
 * navigation either.
 *
 * The scrollbar is hidden rather than the scrolling disabled: trackpads,
 * touch, and shift+wheel still work exactly as before, and the arrows are
 * an addition for everyone else. They hide themselves when there is nothing
 * to scroll to, so a short shelf shows no chrome at all.
 */
export function ScrollRow({ children, label }: ScrollRowProps) {
  const viewport = useRef<HTMLDivElement>(null);
  const [atStart, setAtStart] = useState(true);
  const [atEnd, setAtEnd] = useState(true);

  const measure = useCallback(() => {
    const element = viewport.current;
    if (!element) return;
    const max = element.scrollWidth - element.clientWidth;
    setAtStart(element.scrollLeft <= 1);
    // A pixel of slack: fractional widths mean scrollLeft rarely lands
    // exactly on max, and a permanently enabled arrow reads as broken.
    setAtEnd(element.scrollLeft >= max - 1);
  }, []);

  useEffect(() => {
    const element = viewport.current;
    if (!element) return;

    measure();
    // Covers the cases a scroll listener alone misses: images loading and
    // changing scrollWidth, and the window resizing under a fixed row.
    const observer = new ResizeObserver(measure);
    observer.observe(element);
    for (const child of Array.from(element.children)) observer.observe(child);

    return () => observer.disconnect();
  }, [measure, children]);

  function page(direction: -1 | 1) {
    const element = viewport.current;
    if (!element) return;
    // Not a whole viewport: leaving a sliver of the previous card visible
    // is what tells you the row continued rather than jumped.
    element.scrollBy({ left: direction * element.clientWidth * 0.8, behavior: "smooth" });
  }

  const hidden = atStart && atEnd;

  return (
    <div className="relative">
      <div
        ref={viewport}
        onScroll={measure}
        className="flex gap-3 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
      >
        {children}
      </div>

      {!hidden && (
        <>
          <Arrow
            direction={-1}
            disabled={atStart}
            label={`Scroll ${label} back`}
            onClick={() => page(-1)}
          />
          <Arrow
            direction={1}
            disabled={atEnd}
            label={`Scroll ${label} forward`}
            onClick={() => page(1)}
          />
        </>
      )}
    </div>
  );
}

function Arrow({
  direction,
  disabled,
  label,
  onClick
}: {
  direction: -1 | 1;
  disabled: boolean;
  label: string;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={label}
      className={[
        "absolute top-1/2 z-10 flex h-8 w-8 -translate-y-1/2 items-center justify-center",
        "rounded-pill border border-(--color-separator) bg-(--color-background)",
        "text-(--color-text-primary) shadow-sm transition-opacity",
        disabled ? "pointer-events-none opacity-0" : "opacity-100",
        direction === -1 ? "-left-2" : "-right-2"
      ].join(" ")}
    >
      {direction === -1 ? <ChevronLeftIcon size={16} /> : <ChevronRightIcon size={16} />}
    </button>
  );
}
