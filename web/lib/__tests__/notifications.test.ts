import { describe, expect, it } from "vitest";
import {
  notificationHref,
  notificationSummary,
  toNotification,
  toNotifications,
  type NotificationRow
} from "@/lib/notifications";

const actor = {
  id: "actor-1",
  username: "maya",
  display_name: "Maya Chen",
  avatar_url: null,
  bio: null,
  is_private: false,
  created_at: "2026-01-01T00:00:00Z"
};

function row(overrides: Partial<NotificationRow> = {}): NotificationRow {
  return {
    id: "n1",
    kind: "like",
    created_at: "2026-08-05T12:00:00Z",
    read_at: null,
    post_id: "post-1",
    actor,
    post: { media: { title: "Past Lives" } },
    comment: null,
    ...overrides
  } as NotificationRow;
}

describe("toNotification", () => {
  it("maps a like, including the title it was about", () => {
    const notification = toNotification(row());

    expect(notification?.kind).toBe("like");
    expect(notification?.actor.username).toBe("maya");
    expect(notification?.postTitle).toBe("Past Lives");
    expect(notification?.readAt).toBeNull();
  });

  it("keeps the comment body so the row can quote it", () => {
    const notification = toNotification(
      row({ kind: "comment", comment: { body: "Loved this one." } })
    );

    expect(notification?.commentBody).toBe("Loved this one.");
  });

  it("drops a row whose actor vanished rather than rendering 'someone'", () => {
    // The FK cascades, so this is a race between the delete and the read —
    // but a nameless notification is worse than a missing one.
    expect(toNotification(row({ actor: null as unknown as typeof actor }))).toBeNull();
  });

  it("drops a kind it doesn't understand", () => {
    // A future migration could add one; an old client must not render it as
    // a blank line.
    expect(toNotification(row({ kind: "reaction" }))).toBeNull();
  });

  it("survives a follow row with no post attached", () => {
    const notification = toNotification(
      row({ kind: "follow", post_id: null, post: null, comment: null })
    );

    expect(notification?.postTitle).toBeNull();
    expect(notification?.postId).toBeNull();
  });

  it("filters the bad rows out of a list without failing the page", () => {
    const list = toNotifications([row(), row({ kind: "nonsense" }), row({ id: "n3" })]);
    expect(list.map((item) => item.id)).toEqual(["n1", "n3"]);
  });

  it("returns nothing for a non-array payload", () => {
    expect(toNotifications(null)).toEqual([]);
  });
});

describe("notificationSummary", () => {
  it("names the title when we have one", () => {
    // "liked your post" is forgettable; "liked your post about Past Lives"
    // is the thing worth opening.
    const notification = toNotification(row());
    expect(notification && notificationSummary(notification)).toBe(
      "liked your post about Past Lives"
    );
  });

  it("omits the title when the post has none", () => {
    const notification = toNotification(row({ post: null }));
    expect(notification && notificationSummary(notification)).toBe("liked your post");
  });

  it("distinguishes a follow from a request", () => {
    // A private account's pending request is not a follow yet, and telling
    // someone they have a new follower when they don't is a lie.
    const follow = toNotification(row({ kind: "follow", post_id: null, post: null }));
    const request = toNotification(row({ kind: "follow_request", post_id: null, post: null }));

    expect(follow && notificationSummary(follow)).toBe("started following you");
    expect(request && notificationSummary(request)).toBe("asked to follow you");
  });
});

describe("notificationHref", () => {
  it("sends a like or comment to the post", () => {
    const notification = toNotification(row());
    expect(notification && notificationHref(notification)).toBe("/post/post-1");
  });

  it("sends a follow to the follower's profile", () => {
    const notification = toNotification(
      row({ kind: "follow", post_id: null, post: null, comment: null })
    );
    expect(notification && notificationHref(notification)).toBe("/maya");
  });
});
