"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { MenuIcon } from "@/components/Icon";
import { useUnreadCount } from "@/components/useUnreadCount";

/**
 * The secondary surfaces, folded away behind one control.
 *
 * Feed, Explorer and Profile are where the product lives; Lists, Activity,
 * Settings and Last 12 Months are places you go on purpose. Keeping the
 * latter in the top-level nav made five competing destinations out of
 * three. They now live here and nowhere else — the profile page no longer
 * links Settings or Last 12 Months either, so there is exactly one way to
 * each.
 */
/** Height of the sticky nav, which this hangs from. Matches AppNav's py-3. */
const NAV_HEIGHT = "3.5rem";

const ITEMS = [
  { href: "/settings", label: "Settings" },
  { href: "/lists", label: "Lists" },
  { href: "/notifications", label: "Activity" },
  { href: "/profile/year", label: "Last 12 Months" }
] as const;

interface SideMenuProps {
  /** Unread notifications. Badges both the toggle and the Activity row. */
  unreadCount?: number;
}

export function SideMenu({ unreadCount = 0 }: SideMenuProps) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  // The prop is the server's count at render time; this keeps it current
  // while the page stays open.
  const liveUnread = useUnreadCount(unreadCount);

  // Escape closes it, which is the one keyboard affordance people reach for
  // without being told.
  useEffect(() => {
    if (!open) return;
    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen((wasOpen) => !wasOpen)}
        aria-expanded={open}
        aria-controls="side-menu"
        aria-label={liveUnread > 0 ? `More, ${liveUnread} unread` : "More"}
        className="relative flex h-8 w-8 items-center justify-center rounded-pill text-(--color-text-secondary) hover:text-(--color-text-primary)"
      >
        <MenuIcon size={18} />
        {liveUnread > 0 && !open && (
          <span
            aria-hidden="true"
            className="absolute right-0.5 top-0.5 h-2 w-2 rounded-pill bg-(--color-accent)"
          />
        )}
      </button>

      {open &&
        // Rendered into <body>, not where the toggle sits. The nav carries
        // a backdrop-blur, and a backdrop-filter makes an element the
        // containing block for its `fixed` descendants — so this panel was
        // being positioned and clipped against the nav's own box rather
        // than the viewport, which is why it landed behind the page.
        createPortal(
          <>
            {/* Click-away. Not a focus trap: the panel is four links, and a
                trap that has to be escaped is worse than one that closes.
                Starts below the bar, so the nav stays visible and usable
                with the menu open. */}
            <button
              type="button"
              aria-hidden="true"
              tabIndex={-1}
              onClick={() => setOpen(false)}
              className="fixed inset-x-0 bottom-0 z-40 cursor-default bg-black/20"
              style={{ top: NAV_HEIGHT }}
            />
            <div
              id="side-menu"
              // Hangs from under the bar rather than covering it. Opening
              // the menu should not hide the thing you opened it from.
              className="fixed left-0 z-40 flex w-56 flex-col gap-1 border-r border-(--color-separator) bg-(--color-background) p-4"
              style={{ top: NAV_HEIGHT, height: `calc(100dvh - ${NAV_HEIGHT})` }}
            >
              {ITEMS.map((item) => {
                const active = pathname === item.href;
                const badged = item.href === "/notifications" && liveUnread > 0;
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                    // Closed on click rather than in an effect watching
                    // pathname: React 19's set-state-in-effect rule rejects
                    // that shape, and navigation is user-initiated anyway,
                    // so the event is where the decision belongs.
                    onClick={() => setOpen(false)}
                    className={
                      active
                        ? "rounded-md px-2 py-2 font-semibold text-(--color-accent)"
                        : "rounded-md px-2 py-2 text-(--color-text-primary) hover:bg-(--color-surface)"
                    }
                  >
                    {item.label}
                    {badged && (
                      <span className="ml-2 rounded-pill bg-(--color-accent) px-1.5 py-0.5 text-xs font-semibold text-(--color-on-accent)">
                        {liveUnread > 9 ? "9+" : liveUnread}
                      </span>
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
