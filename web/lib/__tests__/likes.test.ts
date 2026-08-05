import { describe, expect, it } from "vitest";
import { toLikeInfoMap, withDefaults } from "@/lib/likes";

describe("toLikeInfoMap", () => {
  it("keys like info by post id", () => {
    const map = toLikeInfoMap([
      { post_id: "p1", like_count: 3, liked_by_me: true },
      { post_id: "p2", like_count: 0, liked_by_me: false }
    ]);

    expect(map.p1).toEqual({ likeCount: 3, likedByMe: true });
    expect(map.p2).toEqual({ likeCount: 0, likedByMe: false });
  });

  it("coerces the count when PostgREST sends bigint as a string", () => {
    // count() is bigint, which arrives as text — without coercion the UI
    // would compare and render a string.
    const map = toLikeInfoMap([{ post_id: "p1", like_count: "12", liked_by_me: false }]);
    expect(map.p1.likeCount).toBe(12);
  });

  it("treats a missing liked_by_me as not liked", () => {
    const map = toLikeInfoMap([{ post_id: "p1", like_count: 1 }]);
    expect(map.p1.likedByMe).toBe(false);
  });

  it("skips rows with no post id", () => {
    expect(toLikeInfoMap([{ like_count: 5 }])).toEqual({});
  });

  it("returns an empty map for null or a non-array", () => {
    expect(toLikeInfoMap(null)).toEqual({});
    expect(toLikeInfoMap({})).toEqual({});
  });
});

describe("withDefaults", () => {
  it("fills in posts the RPC returned nothing for", () => {
    // Every post gets an entry so callers never branch on "not fetched".
    const complete = withDefaults(["p1", "p2"], { p1: { likeCount: 4, likedByMe: true } });

    expect(complete.p1).toEqual({ likeCount: 4, likedByMe: true });
    expect(complete.p2).toEqual({ likeCount: 0, likedByMe: false });
  });

  it("returns an empty map for no posts", () => {
    expect(withDefaults([], {})).toEqual({});
  });
});
