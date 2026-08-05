import { describe, expect, it } from "vitest";
import { toComment, toCommentCounts, toComments, type CommentRow } from "@/lib/comments";

const author = {
  id: "u1",
  username: "ada",
  display_name: "Ada",
  avatar_url: null,
  bio: null,
  is_private: false,
  created_at: "2026-01-01T00:00:00Z"
};

function row(overrides: Partial<CommentRow> = {}): CommentRow {
  return {
    id: "c1",
    body: "Loved this.",
    created_at: "2026-08-05T10:00:00Z",
    author,
    ...overrides
  };
}

describe("toComment", () => {
  it("maps a complete row", () => {
    const comment = toComment(row());

    expect(comment?.body).toBe("Loved this.");
    expect(comment?.author.username).toBe("ada");
    expect(comment?.createdAt).toBeInstanceOf(Date);
  });

  it("drops a comment whose author embed came back null", () => {
    // Rendering a comment with no name attached is worse than omitting it.
    expect(toComment(row({ author: null as unknown as CommentRow["author"] }))).toBeNull();
  });
});

describe("toComments", () => {
  it("maps a list and drops the unusable ones", () => {
    const comments = toComments([
      row({ id: "c1" }),
      row({ id: "c2", author: null as unknown as CommentRow["author"] })
    ]);
    expect(comments.map((comment) => comment.id)).toEqual(["c1"]);
  });

  it("returns an empty array for null", () => {
    expect(toComments(null)).toEqual([]);
  });
});

describe("toCommentCounts", () => {
  it("keys counts by post id", () => {
    expect(toCommentCounts([{ post_id: "p1", comment_count: 2 }])).toEqual({ p1: 2 });
  });

  it("coerces bigint counts sent as strings", () => {
    expect(toCommentCounts([{ post_id: "p1", comment_count: "7" }])).toEqual({ p1: 7 });
  });

  it("returns an empty map for null", () => {
    expect(toCommentCounts(null)).toEqual({});
  });
});
