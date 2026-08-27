"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { BellIcon, GearIcon, ListIcon, MenuIcon, RewindIcon } from "@/components/Icon";
import { useUnreadCount } from "@/components/useUnreadCount";

/**
 * The secondary surfaces, on a wheel.
 *
 * Feed, Explorer and Profile are where the product lives; Lists, Activity,
 * Settings and Last 12 Months are places you go on purpose. They live here
 * and nowhere else — the profile page no longer links Settings or Last 12
 * Months either, so there is exactly one way to each.
 *
 * Four icons on an arc rather than a drawer down the side. A drawer is a
 * lot of chrome for four links, and it covers the page to show them; the
 * wheel is the four links and nothing else. They unfurl in sequence from
 * the button that opened them, which is where they visibly came from and
 * where closing puts them back.
 *
 * Rendered into the body. The nav carries a backdrop-blur, and a
 * backdrop-filter makes an element the containing block for its fixed
 * descendants — positioned in place, the wheel would be measured against
 * the nav's own box rather than the viewport.
 */
const ITEMS = [
  { href: "/settings", label: "Settings", Icon: GearIcon },
  { href: "/lists", label: "Lists", Icon: ListIcon },
  { href: "/notifications", label: "Activity", Icon: BellIcon },
  { href: "/profile/year", label: "Last 12 Months", Icon: RewindIcon }
] as const;

/**
 * The angle between neighbouring positions on the ring.
 *
 * The radius is not a constant any more — it is measured, so that the ⋯
 * button lands exactly on one of the ring's positions. See `ring` below.
 *
 * Thirty-eight rather than forty for two reasons, both arithmetic. Five
 * slots on a fifty-nine pixel ring leave 2·r·sin(19°) ≈ 38px between
 * neighbouring centres, which 32px icons clear and 40px ones do not. And
 * it keeps the last slot low enough that its icon clears the nav's tab
 * labels on a 360px screen, where the wheel is at its most cramped.
 */
const STEP = 38;
/**
 * A floor, not the working value.
 *
 * It used to be 88, which was larger than the fifty-nine pixels actually
 * separating the wordmark from the ⋯ — so the clamp always won, the ring
 * was half again wider than it needed to be, and the button it was
 * supposed to pass through sat inside it rather than on it. Now the
 * measurement wins and this only catches a layout that has collapsed.
 */
const MIN_RADIUS = 52;
/** Icon diameter, and the margin kept between the wheel and the edges. */
const ICON = 32;
const EDGE = 10;

/** Gap between each icon leaving the centre. The spin. */
const STAGGER_MS = 55;

/** Keeps a value inside a range, however the arithmetic came out. */
function clamp(value: number, low: number, high: number): number {
  return Math.min(high, Math.max(low, value));
}

export function SideMenu({ unreadCount = 0 }: { unreadCount?: number }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  /** Where the wheel comes out of, measured when it opens. */
  const [origin, setOrigin] = useState({ x: 0, y: 0 });
  const [viewport, setViewport] = useState({ width: 0, height: 0 });
  /** Where the ⋯ button sits, which is the ring's first position. */
  const [button, setButton] = useState<{ x: number; y: number } | null>(null);
  /** Set a frame after opening, so the icons animate from the centre out. */
  const [unfurled, setUnfurled] = useState(false);
  const toggle = useRef<HTMLButtonElement>(null);
  const liveUnread = useUnreadCount(unreadCount);

  useEffect(() => {
    if (!open) return;

    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    window.addEventListener("keydown", onKey);
    // One frame at the centre, then out. Without the gap the browser
    // coalesces both states and there is no movement to see.
    const raf = requestAnimationFrame(() => setUnfurled(true));

    return () => {
      window.removeEventListener("keydown", onKey);
      cancelAnimationFrame(raf);
    };
  }, [open]);

  function show() {
    // Two measurements, because the ring is defined by both: it is centred
    // on the wordmark, and its radius is the distance out to the ⋯ button.
    // That is what puts the button on the ring rather than beside it.
    const markBox = document.getElementById("venn-mark")?.getBoundingClientRect();
    const toggleBox = toggle.current?.getBoundingClientRect();
    const centre = markBox ?? toggleBox;
    if (centre) setOrigin({ x: centre.left + centre.width / 2, y: centre.top + centre.height / 2 });
    if (markBox && toggleBox) {
      setButton({
        x: toggleBox.left + toggleBox.width / 2,
        y: toggleBox.top + toggleBox.height / 2
      });
    }
    setViewport({ width: window.innerWidth, height: window.innerHeight });
    setUnfurled(false);
    setOpen(true);
  }

  function hide() {
    setUnfurled(false);
    setOpen(false);
  }

  // Where the fan is centred. Normally the button, but slid inward when
  // that would put part of the arc off the screen — the button sits near
  // the left edge, and on a phone the leftmost icon's natural place is off
  // it entirely. Sliding the whole fan keeps the spacing; clamping each
  // icon separately, which is what this replaced, collapsed them into a
  // pile against the edge.
  // The ring passes through the ⋯ button. Its radius is the distance from
  // the wordmark out to that button, and its first position is the angle
  // the button already sits at — so the button *is* slot zero, and the
  // four icons take the slots after it.
  const ring = (() => {
    const fallback = { radius: 64, start: -90 };
    if (!button) return fallback;
    const dx = button.x - origin.x;
    const dy = button.y - origin.y;
    const radius = Math.max(Math.hypot(dx, dy), MIN_RADIUS);
    if (!Number.isFinite(radius)) return fallback;
    // Angles are measured from straight down, clockwise, matching the
    // sin/cos convention the positions are built with below. The angle is
    // the button's own, so slot zero points at it even where the ring has
    // been opened out past it for room.
    return { radius, start: (Math.atan2(dx, dy) * 180) / Math.PI };
  })();

  const reach = ring.radius;
  const margin = reach + EDGE + ICON / 2;
  const hub = {
    x: viewport.width > margin * 2 ? clamp(origin.x, margin, viewport.width - margin) : origin.x,
    // Not pushed below the nav any more. Wrapping the wordmark means the
    // outer icons sit level with it, over the bar rather than under it —
    // which is what makes the wheel look attached to the mark.
    y: origin.y
  };

  return (
    <>
      <button
        ref={toggle}
        type="button"
        onClick={() => (open ? hide() : show())}
        aria-expanded={open}
        aria-controls="side-menu"
        aria-label={liveUnread > 0 ? `More, ${liveUnread} unread` : "More"}
        className="relative flex h-8 w-8 items-center justify-center rounded-pill text-(--color-text-secondary) hover:text-(--color-text-primary)"
      >
        <MenuIcon size={18} />
        {liveUnread > 0 && !open && (
          <span
            aria-hidden="true"
            className="absolute top-0.5 right-0.5 h-2 w-2 rounded-pill bg-(--color-accent)"
          />
        )}
      </button>

      {open &&
        createPortal(
          <>
            {/* Click-away, and nothing else. Deliberately invisible: the
                page carries on looking like itself behind four icons. */}
            <button
              type="button"
              aria-hidden="true"
              tabIndex={-1}
              onClick={hide}
              className="fixed inset-0 z-40 cursor-default"
            />

            <div id="side-menu" className="pointer-events-none fixed inset-0 z-40">
              {ITEMS.map((item, index) => {
                // Slot zero is the ⋯ button itself, so the icons start at
                // one and step round from there.
                const spread = ring.start + STEP * (index + 1);
                const radians = (spread * Math.PI) / 180;
                // Measured from straight down, so the wheel opens into the
                // page rather than off the top of it.
                const x = hub.x + Math.sin(radians) * ring.radius;
                const y = hub.y + Math.cos(radians) * ring.radius;
                const active = pathname === item.href;
                const badged = item.href === "/notifications" && liveUnread > 0;

                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                    aria-label={item.label}
                    title={item.label}
                    onClick={hide}
                    style={{
                      left: x,
                      top: y,
                      transform: unfurled
                        ? "translate(-50%, -50%) rotate(0deg) scale(1)"
                        : `translate(-50%, -50%) translate(${origin.x - x}px, ${origin.y - y}px) rotate(-120deg) scale(0.3)`,
                      opacity: unfurled ? 1 : 0,
                      transitionDelay: `${index * STAGGER_MS}ms`
                    }}
                    className={[
                      "pointer-events-auto absolute flex h-8 w-8 items-center justify-center",
                      "rounded-pill border border-(--color-separator) bg-(--color-background) shadow-lg",
                      // Reduce Motion gets the icons without the spin — the
                      // wheel is decoration, the four links are not.
                      "transition-all duration-300 ease-out motion-reduce:transition-none",
                      active ? "text-(--color-accent)" : "text-(--color-text-primary)"
                    ].join(" ")}
                  >
                    <item.Icon size={17} />
                    {badged && (
                      <span
                        aria-hidden="true"
                        className="absolute -top-0.5 -right-0.5 h-2.5 w-2.5 rounded-pill bg-(--color-accent)"
                      />
                    )}
                  </Link>
                );
              })}
            </div>
          </>,
          document.body
        )}
    </>
  );
}
