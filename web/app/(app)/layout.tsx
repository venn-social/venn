import { AppNav } from "@/components/AppNav";
import { LaunchSplash } from "@/components/LaunchSplash";
import { fetchUnreadCount } from "@/lib/notifications";
import { createClient } from "@/lib/supabase/server";

/**
 * Shell for signed-in pages. Pages under (auth) — login, onboarding —
 * deliberately get no nav: there is nothing useful to navigate to before
 * you have a profile. Route groups don't affect URLs, so /profile is
 * still /profile.
 *
 * The unread count is fetched here rather than inside `AppNav` so the badge
 * arrives with the HTML instead of appearing a beat later on every page.
 * `AppNav` stays a client component only because it needs `usePathname`.
 */
export default async function AppLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  // A failed count must not take the whole shell down with it — every
  // signed-in page renders through here. No badge is the right fallback.
  let unreadCount = 0;
  try {
    unreadCount = await fetchUnreadCount(supabase);
  } catch {
    unreadCount = 0;
  }

  return (
    <>
      <LaunchSplash />
      <AppNav unreadCount={unreadCount} userId={user?.id ?? null} />
      {children}
    </>
  );
}
