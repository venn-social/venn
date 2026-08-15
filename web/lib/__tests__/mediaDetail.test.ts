import { describe, expect, it } from "vitest";
import { EMPTY_DETAIL } from "@/lib/catalog/detail";

describe("unavailable vs empty", () => {
  it("does not mark a genuinely empty result as unavailable", () => {
    // A book with no cast is not a failed request. Flagging it would put a
    // retry button under every item the provider simply knows little about.
    expect(EMPTY_DETAIL.unavailable).toBeUndefined();
  });
});
