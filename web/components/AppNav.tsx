"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

/**
 * Persistent nav for authenticated pages. Order matches iOS's tab bar
 * exactly — Feed, Explorer, Profile — followed by the accent "Log" action.
 *
 * Follow requests deliberately stay off the nav and are reached from the
 * profile page, matching where iOS puts them (ProfileView's top bar, and
 * only for private accounts).
 */
const TABS = [
  { href: "/feed", label: "Feed" },
  { href: "/explorer", label: "Explorer" },
  { href: "/lists", label: "Lists" },
  { href: "/profile", label: "Profile" }
] as const;

export function AppNav() {
  const pathname = usePathname();

  return (
    <nav className="sticky top-0 z-10 border-b border-(--color-separator) bg-(--color-background)">
      <ul className="mx-auto flex max-w-lg items-center gap-6 px-4 py-3">
        <li className="mr-auto font-semibold text-(--color-text-primary)">venn</li>
        {TABS.map((tab) => {
          const active = pathname === tab.href;
          return (
            <li key={tab.href}>
              <Link
                href={tab.href}
                aria-current={active ? "page" : undefined}
                className={
                  active
                    ? "font-semibold text-(--color-accent)"
                    : "text-(--color-text-secondary) hover:text-(--color-text-primary)"
                }
              >
                {tab.label}
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
