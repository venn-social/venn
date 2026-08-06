import { redirect } from "next/navigation";
import { NotificationRow } from "@/components/NotificationRow";
import { fetchNotifications, markAllRead } from "@/lib/notifications";
import { createClient } from "@/lib/supabase/server";

/**
 * Everything that happened to you: likes, comments, follows, and follow
 * requests. Mirrors iOS's `NotificationsView` in copy and ordering.
 *
 * Until this existed the social loop only ran one way — you could like
 * someone's post and they would never find out unless they happened to open
 * it again.
 */
export default async function NotificationsPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  let notifications;
  try {
    notifications = await fetchNotifications(supabase);
  } catch {
    return (
      <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
        <h1 className="text-xl font-semibold text-(--color-text-primary)">Activity</h1>
        <p className="text-(--color-text-secondary)">Couldn&apos;t load your activity.</p>
      </main>
    );
  }

  // Read *after* fetching, so this render still shows which rows were new.
  // The badge clears now; the tint on those rows survives until the next
  // visit, which is the honest order — you have in fact just seen them.
  //
  // A failure here leaves the badge up. That's the safe direction: a badge
  // that lingers is a nuisance, one that clears without the user seeing the
  // rows loses the notification entirely.
  try {
    await markAllRead(supabase);
  } catch {
    // Deliberately ignored — see above.
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 py-8">
      <h1 className="px-4 text-xl font-semibold text-(--color-text-primary)">Activity</h1>

      {notifications.length === 0 ? (
        <div className="flex flex-col gap-1 px-4 py-12 text-center">
          <p className="font-semibold text-(--color-text-primary)">Nothing yet</p>
          <p className="text-(--color-text-secondary)">
            Likes, comments, and new followers show up here.
          </p>
        </div>
      ) : (
        <ul className="flex flex-col divide-y divide-(--color-separator)">
          {notifications.map((notification) => (
            <NotificationRow key={notification.id} notification={notification} />
          ))}
        </ul>
      )}
    </main>
  );
}
