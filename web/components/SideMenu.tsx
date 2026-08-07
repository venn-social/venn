"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { MenuIcon } from "@/components/Icon";

/**
 * The secondary surfaces, folded away behind one control.
 *
 * Feed, Explorer and Profile are where the product lives; Lists, Activity,
 * Settings and Year in Review are places you go on purpose. Keeping the
 * latter in the top-level nav made five competing destinations out of
 * three. They now live here and nowhere else — the profile page no longer
 * links Settings or Year in Review either, so there is exactly one way to
 * each.
 */
const ITEMS = [
  { href: "/settings", label: "Settings" },
  { href: "/lists", label: "Lists" },
  { href: "/notifications", label: "Activity" },
  { href: "/profile/year", label: "Year in Review" },
] as const;

interface SideMenuProps {
  /** Unread notifications. Badges both the toggle and the Activity row. */
  unreadCount?: number;
}

export function SideMenu({ unreadCount = 0 }: SideMenuProps) {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

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
        aria-label={
          unreadCount > 0 ? `More, ${unreadCount} unread` : "More"
        }
        className="relative flex h-8 w-8 items-center justify-center rounded-pill text-(--color-text-secondary) hover:text-(--color-text-primary)"
      >
        <MenuIcon size={18} />
        {unreadCount > 0 && !open && (
          <span
            aria-hidden="true"
            className="absolute right-0.5 top-0.5 h-2 w-2 rounded-pill bg-(--color-accent)"
          />
        )}
      </button>

      {open && (
        <>
          {/* Click-away. Not a focus trap: the panel is four links, and a
              trap that has to be escaped is worse than one that closes. */}
          <button
            type="button"
            aria-hidden="true"
            tabIndex={-1}
            onClick={() => setOpen(false)}
            className="fixed inset-0 z-20 cursor-default bg-black/20"
          />
          <div
            id="side-menu"
            className="fixed right-0 top-0 z-30 flex h-full w-56 flex-col gap-1 border-l border-(--color-separator) bg-(--color-background) p-4"
          >
            {ITEMS.map((item) => {
              const active = pathname === item.href;
              const badged = item.href === "/notifications" && unreadCount > 0;
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  aria-current={active ? "page" : undefined}
                  // Closed on click rather than in an effect watching
                  // pathname: React 19's set-state-in-effect rule rejects
                  // that shape, and navigation is user-initiated anyway, so
                  // the event is where the decision belongs.
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
                      {unreadCount > 9 ? "9+" : unreadCount}
                    </span>
                  )}
                </Link>
              );
            })}
          </div>
        </>
      )}
    </>
  );
}
