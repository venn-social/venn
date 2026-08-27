"use client";

import { useEffect, useRef, useState } from "react";
import { MoreIcon } from "@/components/Icon";

export interface OverflowAction {
  label: string;
  onSelect: () => void;
  /** Renders in red. For removals. */
  destructive?: boolean;
  /** Required by the "icons" presentation, ignored by the other. */
  icon?: React.ReactNode;
}

interface MediaOverflowMenuProps {
  /** Names the menu for assistive tech, e.g. "Options for Piranesi". */
  label: string;
  actions: OverflowAction[];
  /** Set while a chosen action is in flight. */
  busy?: boolean;
  /** Which corner of the artwork it sits in. Defaults to the right. */
  align?: "left" | "right";
  /**
   * "menu" is a panel of labelled rows. "icons" drops the actions straight
   * down the artwork as bare glyphs — no panel, no words — for surfaces
   * that already carry a scrim to make them legible.
   */
  presentation?: "menu" | "icons";
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
export function MediaOverflowMenu({
  label,
  actions,
  busy = false,
  align = "right",
  presentation = "menu"
}: MediaOverflowMenuProps) {
  const bare = presentation === "icons";
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
    <div
      ref={containerRef}
      className={`absolute top-1 z-10 ${align === "left" ? "left-1" : "right-1"}`}
    >
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
          "flex h-7 w-7 items-center justify-center rounded-pill text-white",
          // Bare over a scrim, which is already doing the work a pill was
          // doing before; still a pill where there is no scrim behind it.
          bare
            ? "[filter:drop-shadow(0_1px_2px_rgb(0_0_0/0.85))_drop-shadow(0_0_5px_rgb(0_0_0/0.45))]"
            : "bg-black/55 backdrop-blur-sm",
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
          className={
            bare
              ? // Straight down the artwork from the button, in its column.
                `absolute top-8 flex flex-col items-center gap-1 ${align === "left" ? "left-0" : "right-0"}`
              : `absolute top-8 min-w-36 overflow-hidden rounded-md border border-(--color-separator) bg-(--color-background) py-1 shadow-lg ${align === "left" ? "left-0" : "right-0"}`
          }
        >
          {actions.map((action) => (
            <button
              key={action.label}
              type="button"
              role="menuitem"
              // The words survive as the accessible name and the tooltip.
              // A glyph nobody can name is a glyph nobody can use.
              aria-label={bare ? action.label : undefined}
              title={bare ? action.label : undefined}
              onClick={(event) => {
                event.preventDefault();
                event.stopPropagation();
                setOpen(false);
                action.onSelect();
              }}
              className={
                bare
                  ? [
                      "flex h-7 w-7 items-center justify-center rounded-pill text-white",
                      "[filter:drop-shadow(0_1px_2px_rgb(0_0_0/0.85))_drop-shadow(0_0_5px_rgb(0_0_0/0.45))] transition-opacity hover:opacity-70",
                      action.destructive ? "text-red-400" : ""
                    ].join(" ")
                  : [
                      "block w-full px-3 py-2 text-left text-sm hover:bg-(--color-surface)",
                      action.destructive ? "text-red-500" : "text-(--color-text-primary)"
                    ].join(" ")
              }
            >
              {bare ? action.icon : action.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
