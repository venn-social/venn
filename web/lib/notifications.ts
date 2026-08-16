import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

/** What happened. Mirrors the `notifications_kind_valid` CHECK. */
export type NotificationKind = "like" | "comment" | "follow" | "follow_request" | "reply";

export interface AppNotification {
  id: string;
  kind: NotificationKind;
  /** Who caused it. */
  actor: UserProfile;
  createdAt: Date;
  readAt: Date | null;
  /** Set for like and comment; null for the follow kinds. */
  postId: string | null;
  /** The media title the post is about, for "liked your post about Past Lives". */
  postTitle: string | null;
  /** The comment's text, so the row can quote it rather than just announce it. */
  commentBody: string | null;
}

export interface NotificationRow {
  id: string;
  kind: string;
  created_at: string;
  read_at: string | null;
  post_id: string | null;
  actor: ProfileRow;
  post: { media: { title: string } | null } | null;
  comment: { body: string } | null;
}

const KINDS: readonly string[] = ["like", "comment", "follow", "follow_request", "reply"];

export function toNotification(row: NotificationRow): AppNotification | null {
  // A row whose actor vanished mid-flight would render as "someone", which
  // is worse than not rendering it. The FK cascades, so this is a race, not
  // a steady state.
  if (!row.actor) return null;
  if (!KINDS.includes(row.kind)) return null;

  return {
    id: row.id,
    kind: row.kind as NotificationKind,
    actor: toUserProfile(row.actor),
    createdAt: new Date(row.created_at),
    readAt: row.read_at ? new Date(row.read_at) : null,
    postId: row.post_id,
    postTitle: row.post?.media?.title ?? null,
    commentBody: row.comment?.body ?? null
  };
}

export function toNotifications(rows: unknown): AppNotification[] {
  if (!Array.isArray(rows)) return [];
  return (rows as NotificationRow[])
    .map(toNotification)
    .filter((notification): notification is AppNotification => notification !== null);
}

/**
 * Your notifications, newest first.
 *
 * The foreign keys are named explicitly for the same reason the feed query
 * has to: `notifications` points at `profiles` twice (recipient and actor),
 * so a bare `profiles(*)` embed is ambiguous and fails with PGRST201. That
 * exact mistake took the feed down on both platforms once already.
 */
export async function fetchNotifications(
  client: SupabaseClient,
  limit = 50
): Promise<AppNotification[]> {
  const { data, error } = await client
    .from("notifications")
    .select(
      "id, kind, created_at, read_at, post_id, " +
        "actor:profiles!notifications_actor_id_fkey(*), " +
        "post:posts(media(title)), " +
        "comment:post_comments(body)"
    )
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return toNotifications(data);
}

/**
 * How many are unread.
 *
 * Goes through the RPC rather than a client-side count so the badge is one
 * round trip with no rows transferred — it renders on every signed-in page.
 */
export async function fetchUnreadCount(client: SupabaseClient): Promise<number> {
  const { data, error } = await client.rpc("unread_notification_count");
  if (error) throw error;
  // bigint arrives as a string over PostgREST.
  return Number(data ?? 0);
}

/**
 * Clear the badge. Marks everything unread rather than taking ids: the
 * screen shows them all at once, so anything narrower would leave the badge
 * claiming there's something left to see.
 */
export async function markAllRead(client: SupabaseClient): Promise<number> {
  const { data, error } = await client.rpc("mark_notifications_read");
  if (error) throw error;
  return Number(data ?? 0);
}

/** Where tapping the row should go. */
export function notificationHref(notification: AppNotification): string {
  if (notification.postId) return `/post/${notification.postId}`;
  return `/${notification.actor.username}`;
}

/**
 * The sentence a row shows.
 *
 * Copy is shared with iOS (`NotificationKind.summary`) — CLAUDE.md rule 17.
 * The title is included when we have it because "liked your post" is
 * forgettable and "liked your post about Past Lives" is not.
 */
export function notificationSummary(notification: AppNotification): string {
  const about = notification.postTitle ? ` about ${notification.postTitle}` : "";

  switch (notification.kind) {
    case "like":
      return `liked your post${about}`;
    case "comment":
      return `commented on your post${about}`;
    case "reply":
      // Not "commented on your post": a reply can land on a stranger's post,
      // and telling someone you commented on a post they do not own is a
      // small lie that makes the whole feed less trustworthy.
      return `replied to your comment${about}`;
    case "follow":
      return "started following you";
    case "follow_request":
      return "asked to follow you";
  }
}
