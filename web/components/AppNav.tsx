"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

/**
 * Persistent nav for authenticated pages. Order matches iOS's tab bar
 * exactly — Feed, Explorer, Lists, Activity, Profile — followed by the
 * accent "Log" action.
 *
 * Follow requests deliberately stay off the nav and are reached from the
 * profile page, matching where iOS puts them (ProfileView's top bar, and
 * only for private accounts).
 */
const TABS = [
  { href: "/feed", label: "Feed" },
  { href: "/explorer", label: "Explorer" },
  { href: "/lists", label: "Lists" },
  { href: "/notifications", label: "Activity" },
  { href: "/profile", label: "Profile" }
] as const;

interface AppNavProps {
  /** Unread notifications. Rendered as a badge on Activity; 0 hides it. */
  unreadCount?: number;
}

export function AppNav({ unreadCount = 0 }: AppNavProps) {
  const pathname = usePathname();

  return (
    <nav className="sticky top-0 z-10 border-b border-(--color-separator) bg-(--color-background)">
      <ul className="mx-auto flex max-w-lg items-center gap-6 px-4 py-3">
        <li className="mr-auto font-semibold text-(--color-text-primary)">venn</li>
        {TABS.map((tab) => {
          const active = pathname === tab.href;
          const badged = tab.href === "/notifications" && unreadCount > 0;
          return (
            <li key={tab.href}>
              <Link
                href={tab.href}
                aria-current={active ? "page" : undefined}
                // The badge is capped at "9+" visually, so the real number
                // has to reach a screen reader some other way. Labelling the
                // link says it once and exactly; a visually-hidden span next
                // to the digits would announce the count twice.
                aria-label={badged ? `${tab.label}, ${unreadCount} unread` : undefined}
                className={
                  active
                    ? "font-semibold text-(--color-accent)"
                    : "text-(--color-text-secondary) hover:text-(--color-text-primary)"
                }
              >
                {tab.label}
                {badged && (
                  <span className="ml-1 rounded-pill bg-(--color-accent) px-1.5 py-0.5 text-xs font-semibold text-(--color-on-accent)">
                    {unreadCount > 9 ? "9+" : unreadCount}
                  </span>
                )}
              </Link>
            </li>
          );
        })}
        <li>
          <Link
            href="/composer"
            className="rounded-pill bg-(--color-accent) px-3 py-1.5 text-sm font-semibold text-(--color-on-accent)"
          >
            Log
          </Link>
        </li>
      </ul>
    </nav>
  );
}
