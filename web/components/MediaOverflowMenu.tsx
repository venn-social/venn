"use client";

import { useEffect, useRef, useState } from "react";
import { MoreIcon } from "@/components/Icon";

export interface OverflowAction {
  label: string;
  onSelect: () => void;
  /** Renders in red. For removals. */
  destructive?: boolean;
}

interface MediaOverflowMenuProps {
  /** Names the menu for assistive tech, e.g. "Options for Piranesi". */
  label: string;
  actions: OverflowAction[];
  /** Set while a chosen action is in flight. */
  busy?: boolean;
}

/**
 * The ⋯ control that sits over a piece of artwork.
 *
 * Revealed on hover, but **only where hovering exists**. The parent marks
 * itself `group` and this hides via `group-hover`; on touch, where no
 * hover event will ever fire, `hover-none:opacity-100` keeps it visible.
 * A control that appears only on hover is a control a phone user does not
 * have.
 */
export function MediaOverflowMenu({ label, actions, busy = false }: MediaOverflowMenuProps) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;

    function onPointerDown(event: MouseEvent) {
      if (!containerRef.current?.contains(event.target as Node)) setOpen(false);
    }
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    window.addEventListener("mousedown", onPointerDown);
    window.addEventListener("keydown", onKey);
    return () => {
      window.removeEventListener("mousedown", onPointerDown);
      window.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={containerRef} className="absolute right-1 top-1 z-10">
      <button
        type="button"
        aria-label={label}
        aria-haspopup="menu"
        aria-expanded={open}
        disabled={busy}
        onClick={(event) => {
          // The artwork behind this is a link to the media page.
          event.preventDefault();
          event.stopPropagation();
          setOpen((wasOpen) => !wasOpen);
        }}
        className={[
          "flex h-7 w-7 items-center justify-center rounded-pill",
          "bg-black/55 text-white backdrop-blur-sm",
          "opacity-0 transition-opacity group-hover:opacity-100 focus-visible:opacity-100",
          "hover-none:opacity-100",
          open ? "opacity-100" : "",
          busy ? "cursor-progress" : ""
        ].join(" ")}
      >
        <MoreIcon size={16} />
      </button>

      {open && (
        <div
          role="menu"
          className="absolute right-0 top-8 min-w-36 overflow-hidden rounded-md border border-(--color-separator) bg-(--color-background) py-1 shadow-lg"
        >
          {actions.map((action) => (
            <button
              key={action.label}
              type="button"
              role="menuitem"
              onClick={(event) => {
                event.preventDefault();
                event.stopPropagation();
                setOpen(false);
                action.onSelect();
              }}
              className={[
                "block w-full px-3 py-2 text-left text-sm hover:bg-(--color-surface)",
                action.destructive ? "text-red-500" : "text-(--color-text-primary)"
              ].join(" ")}
            >
              {action.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
