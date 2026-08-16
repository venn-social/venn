import { toUserProfile } from "@/lib/profile";
import { describe, expect, it } from "vitest";
import { toComment, toCommentCounts, toComments, toThreads, type CommentRow, type PostComment } from "@/lib/comments";

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

describe("edited comments", () => {
  it("carries the edited marker through from the row", () => {
    const comment = toComment({
      id: "c1",
      body: "corrected",
      created_at: "2026-08-15T10:00:00Z",
      edited_at: "2026-08-15T10:05:00Z",
      author
    });
    expect(comment?.editedAt).toEqual(new Date("2026-08-15T10:05:00Z"));
  });

  it("leaves the marker null on a comment nobody has edited", () => {
    const comment = toComment({
      id: "c1",
      body: "as written",
      created_at: "2026-08-15T10:00:00Z",
      edited_at: null,
      author
    });
    expect(comment?.editedAt).toBeNull();
  });

  it("treats a row with no edited_at at all as unedited", () => {
    // Older rows predate the column, and a missing field must not read as
    // an edit that never happened.
    const comment = toComment({
      id: "c1",
      body: "as written",
      created_at: "2026-08-15T10:00:00Z",
      author
    });
    expect(comment?.editedAt).toBeNull();
  });
});

describe("toThreads", () => {
  function at(id: string, minute: number, parentId: string | null = null): PostComment {
    return {
      id,
      body: id,
      createdAt: new Date(`2026-08-16T10:${String(minute).padStart(2, "0")}:00Z`),
      editedAt: null,
      parentId,
      author: toUserProfile(author)!
    };
  }

  it("groups replies under their root, oldest first", () => {
    const threads = toThreads([at("root", 0), at("b", 2, "root"), at("a", 1, "root")]);
    expect(threads).toHaveLength(1);
    expect(threads[0].replies.map((reply) => reply.id)).toEqual(["a", "b"]);
  });

  it("orders roots oldest first, like the conversation happened", () => {
    const threads = toThreads([at("second", 5), at("first", 1)]);
    expect(threads.map((thread) => thread.comment.id)).toEqual(["first", "second"]);
  });

  it("leaves a root with no replies alone", () => {
    const threads = toThreads([at("solo", 0)]);
    expect(threads[0].replies).toEqual([]);
  });

  it("promotes a reply whose root is missing rather than dropping it", () => {
    // Happens when a thread is paginated. Losing someone's words is worse
    // than showing them slightly out of place.
    const threads = toThreads([at("orphan", 3, "not-here")]);
    expect(threads.map((thread) => thread.comment.id)).toEqual(["orphan"]);
  });

  it("does not nest a reply under another reply", () => {
    // The database refuses this, but the grouping must not invent it either
    // if a row ever arrives that way.
    const threads = toThreads([at("root", 0), at("a", 1, "root"), at("b", 2, "a")]);
    expect(threads[0].replies.map((reply) => reply.id)).toEqual(["a"]);
    // "b" has a parent that is not a root, so it surfaces as its own thread.
    expect(threads.map((thread) => thread.comment.id)).toEqual(["root", "b"]);
  });

  it("returns nothing for no comments", () => {
    expect(toThreads([])).toEqual([]);
  });
});
