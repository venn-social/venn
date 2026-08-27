import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import { notificationHref, notificationSummary, type AppNotification } from "@/lib/notifications";
import { shortRelativeTime } from "@/lib/relativeTime";

interface NotificationRowProps {
  notification: AppNotification;
}

/**
 * One line of activity: who, what, when.
 *
 * Unread rows carry a tinted background rather than a dot, because the
 * whole list is marked read the moment the page renders — a per-row dot
 * would be stale by the time anyone looked at it. The tint is the record of
 * what arrived since last time.
 */
export function NotificationRow({ notification }: NotificationRowProps) {
  const name = notification.actor.displayName ?? notification.actor.username;

  return (
    <li className={notification.readAt ? "" : "rounded-2xl bg-(--color-surface)"}>
      <Link href={notificationHref(notification)} className="flex items-start gap-3 px-4 py-3">
        <Avatar name={name} avatarUrl={notification.actor.avatarUrl} size={36} />

        <div className="flex min-w-0 flex-col gap-0.5">
          <p className="text-(--color-text-primary)">
            <span className="font-semibold">{name}</span>{" "}
            <span className="text-(--color-text-secondary)">
              {notificationSummary(notification)}
            </span>
          </p>

          {notification.commentBody && (
            <p className="truncate text-sm text-(--color-text-secondary)">
              &ldquo;{notification.commentBody}&rdquo;
            </p>
          )}
        </div>

        <span className="ml-auto shrink-0 text-xs text-(--color-text-secondary)">
          {shortRelativeTime(notification.createdAt)}
        </span>
      </Link>
    </li>
  );
}
