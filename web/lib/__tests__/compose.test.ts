import { describe, expect, it } from "vitest";
import { isRateLimited, ratingToPost } from "@/lib/compose";

describe("ratingToPost", () => {
  it("maps Love to a rated post at 5", () => {
    expect(ratingToPost("love")).toEqual({ action: "rated", rating: 5 });
  });

  it("maps Like to a rated post at 3", () => {
    expect(ratingToPost("like")).toEqual({ action: "rated", rating: 3 });
  });

  it("maps Dislike to a rated post at 1", () => {
    expect(ratingToPost("dislike")).toEqual({ action: "rated", rating: 1 });
  });

  it("maps skip to a plain logged post with no rating", () => {
    expect(ratingToPost(null)).toEqual({ action: "logged", rating: null });
  });
});

describe("isRateLimited", () => {
  it("recognises the P0429 the posts trigger raises", () => {
    expect(isRateLimited({ code: "P0429" })).toBe(true);
  });

  it("does not treat other Postgres errors as rate limiting", () => {
    expect(isRateLimited({ code: "23505" })).toBe(false);
    expect(isRateLimited(new Error("network"))).toBe(false);
    expect(isRateLimited(null)).toBe(false);
  });
});
