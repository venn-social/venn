"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

/**
 * Persistent nav for authenticated pages, mirroring iOS's tab bar
 * (Feed / Explorer / Profile). Explorer renders disabled until that phase
 * ships — showing the final shape without offering a dead link.
 *
 * Follow requests deliberately stay off the nav and are reached from the
 * profile page, matching where iOS puts them (ProfileView's top bar, and
 * only for private accounts).
 */
const TABS = [
  { href: "/feed", label: "Feed" },
  { href: "/profile", label: "Profile" },
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
          <span aria-disabled="true" title="Coming soon" className="text-(--color-separator)">
            Explorer
          </span>
        </li>
      </ul>
    </nav>
  );
}
