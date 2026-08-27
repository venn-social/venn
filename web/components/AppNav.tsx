"use client";

import Link from "next/link";
import { ComposerLauncher } from "@/components/ComposerLauncher";
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
  /**
   * The viewer, so the composer can open over the current page. Null falls
   * back to the standalone route, which redirects if they are signed out.
   */
  userId?: string | null;
}

export function AppNav({ unreadCount = 0, userId = null }: AppNavProps) {
  const pathname = usePathname();

  return (
    // No bottom rule: the nav reads as floating over the page rather
    // than as a bar bolted to the top of it. The translucent ground
    // plus a blur keeps the labels legible while content passes
    // beneath, which a flat opaque strip with no edge could not.
    <nav className="sticky top-0 z-30 bg-(--color-background)/80 backdrop-blur-md">
      <ul className="mx-auto flex max-w-lg items-center gap-6 px-4 py-3 lg:max-w-4xl xl:max-w-6xl">
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
          {/* Opens over whatever you are looking at. Logging is a detour by
              nature — you are always in the middle of something else when
              you decide to log — so being sent to a page and having to come
              back was the wrong shape. Signed-out or scripted callers still
              get the real route. */}
          {userId ? (
            <ComposerLauncher
              userId={userId}
              label="Log"
              className="flex h-8 w-8 items-center justify-center rounded-pill bg-(--color-accent) text-(--color-on-accent)"
            >
              <PlusIcon size={18} />
            </ComposerLauncher>
          ) : (
            <Link
              href="/composer"
              aria-label="Log"
              className="flex h-8 w-8 items-center justify-center rounded-pill bg-(--color-accent) text-(--color-on-accent)"
            >
              <PlusIcon size={18} />
            </Link>
          )}
        </li>
      </ul>
    </nav>
  );
}
