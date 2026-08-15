"use client";

import Link from "next/link";
import { PlusIcon } from "@/components/Icon";
import { SideMenu } from "@/components/SideMenu";
import { usePathname } from "next/navigation";

/**
 * Persistent nav for authenticated pages: the secondary-surfaces control on
 * the leading edge, then the three places the product lives, then the accent
 * "Log" action.
 *
 * Lists, Activity, Settings and Last 12 Months moved into `SideMenu`. Five
 * top-level destinations meant none of them read as primary; these three
 * are where you actually spend time, and the rest are somewhere you go on
 * purpose.
 *
 * Follow requests deliberately stay off the nav and are reached from the
 * profile page, matching where iOS puts them (ProfileView's top bar, and
 * only for private accounts).
 */
const TABS = [
  { href: "/feed", label: "Feed" },
  { href: "/explorer", label: "Explorer" },
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
        <li>
          <SideMenu unreadCount={unreadCount} />
        </li>
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
            // Same pill, same accent — just the glyph instead of the word.
            // The label moves to aria-label so it still announces as "Log".
            aria-label="Log"
            className="flex h-8 w-8 items-center justify-center rounded-pill bg-(--color-accent) text-(--color-on-accent)"
          >
            <PlusIcon size={18} />
          </Link>
        </li>
      </ul>
    </nav>
  );
}
