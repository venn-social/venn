import { describe, expect, it } from "vitest";
import { feedCursor, toFeedPost, type FeedPostRow } from "@/lib/feed";

const authorRow = {
  id: "11111111-1111-1111-1111-111111111111",
  username: "ada",
  display_name: "Ada",
  avatar_url: null,
  bio: null,
  is_private: false,
  created_at: "2026-01-01T00:00:00Z",
};

function row(overrides: Partial<FeedPostRow> = {}): FeedPostRow {
  return {
    id: "22222222-2222-2222-2222-222222222222",
    author_id: authorRow.id,
    media_id: "33333333-3333-3333-3333-333333333333",
    action: "logged",
    rating: null,
    caption: null,
    created_at: "2026-08-01T10:00:00Z",
    media: {
      id: "33333333-3333-3333-3333-333333333333",
      kind: "movie",
      title: "Past Lives",
      year: 2023,
      primary_creator: "Celine Song",
      cover_url: "https://example.test/cover.jpg",
    },
    author: authorRow,
    ...overrides,
  };
}

describe("toFeedPost", () => {
  it("maps a complete row into the domain shape", () => {
    const post = toFeedPost(row({ rating: 4.5, caption: "Devastating." }));

    expect(post).not.toBeNull();
    expect(post?.media.title).toBe("Past Lives");
    expect(post?.media.year).toBe(2023);
    expect(post?.media.primaryCreator).toBe("Celine Song");
    expect(post?.rating).toBe(4.5);
    expect(post?.caption).toBe("Devastating.");
    expect(post?.author.username).toBe("ada");
    expect(post?.createdAt).toBeInstanceOf(Date);
  });

  it("drops a post whose action is not a known value", () => {
    // Forwards-compat: a new post_action shipped server-side must not
    // break an already-deployed client.
    expect(toFeedPost(row({ action: "yodelled" as FeedPostRow["action"] }))).toBeNull();
  });

  it("drops a post whose media kind is not a known value", () => {
    const bad = row();
    bad.media.kind = "hologram" as FeedPostRow["media"]["kind"];
    expect(toFeedPost(bad)).toBeNull();
  });

  it("keeps a post with no rating, caption, year, creator, or cover", () => {
    const sparse = row();
    sparse.media.year = null;
    sparse.media.primary_creator = null;
    sparse.media.cover_url = null;

    const post = toFeedPost(sparse);

    expect(post).not.toBeNull();
    expect(post?.media.year).toBeNull();
    expect(post?.media.coverUrl).toBeNull();
    expect(post?.rating).toBeNull();
    expect(post?.caption).toBeNull();
  });
});

describe("feedCursor", () => {
  it("keeps fractional seconds", () => {
    // Without milliseconds, every post created in the same second as the
    // cursor is skipped on the next page.
    expect(feedCursor(new Date("2026-08-01T10:00:00.123Z"))).toBe("2026-08-01T10:00:00.123Z");
  });
});
