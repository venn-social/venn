"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { BellIcon, ChartIcon, GearIcon, ListIcon, MenuIcon } from "@/components/Icon";
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
  { href: "/profile/year", label: "Last 12 Months", Icon: ChartIcon }
] as const;

/**
 * How far the icons sit from the button they came out of.
 *
 * Chosen with the arc below so adjacent icons clear each other: four 44px
 * icons over 90 degrees need roughly 60px of chord between them, which is
 * what this radius gives. Tighter and they overlap.
 */
const RADIUS = 118;
/**
 * The arc they occupy, in degrees either side of straight down.
 *
 * Symmetric and downward: an arc that swept up put the last icon back
 * under the nav it came from, which is the one place it must not go.
 */
const ARC_START = -45;
const ARC_END = 45;
/** Gap between each icon leaving the centre. The spin. */
const STAGGER_MS = 55;

export function SideMenu({ unreadCount = 0 }: { unreadCount?: number }) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  /** Where the wheel comes out of, measured when it opens. */
  const [origin, setOrigin] = useState({ x: 0, y: 0 });
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
    const box = toggle.current?.getBoundingClientRect();
    if (box) setOrigin({ x: box.left + box.width / 2, y: box.top + box.height / 2 });
    setUnfurled(false);
    setOpen(true);
  }

  function hide() {
    setUnfurled(false);
    setOpen(false);
  }

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
                const spread = ARC_START + ((ARC_END - ARC_START) * index) / (ITEMS.length - 1);
                const radians = (spread * Math.PI) / 180;
                // Measured from straight down, so the wheel opens into the
                // page rather than off the top of it.
                const x = Math.sin(radians) * RADIUS;
                const y = Math.cos(radians) * RADIUS;
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
                      left: origin.x,
                      top: origin.y,
                      transform: unfurled
                        ? `translate(-50%, -50%) translate(${x}px, ${y}px) rotate(0deg) scale(1)`
                        : "translate(-50%, -50%) rotate(-120deg) scale(0.3)",
                      opacity: unfurled ? 1 : 0,
                      transitionDelay: `${index * STAGGER_MS}ms`
                    }}
                    className={[
                      "pointer-events-auto absolute flex h-11 w-11 items-center justify-center",
                      "rounded-pill border border-(--color-separator) bg-(--color-background) shadow-lg",
                      // Reduce Motion gets the icons without the spin — the
                      // wheel is decoration, the four links are not.
                      "transition-all duration-300 ease-out motion-reduce:transition-none",
                      active ? "text-(--color-accent)" : "text-(--color-text-primary)"
                    ].join(" ")}
                  >
                    <item.Icon size={19} />
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
