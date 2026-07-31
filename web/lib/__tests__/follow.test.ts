import { describe, expect, it } from "vitest";
import { mapFollowerRows, type FollowerRow } from "@/lib/follow";
import type { ProfileRow } from "@/lib/profile";

function makeProfileRow(username: string): ProfileRow {
  return {
    id: `${username}-id`,
    username,
    display_name: null,
    avatar_url: null,
    bio: null,
    is_private: false,
    created_at: "2026-05-01T00:00:00Z"
  };
}

describe("mapFollowerRows", () => {
  it("maps embedded follower profiles to UserProfile", () => {
    const rows: FollowerRow[] = [
      { follower: makeProfileRow("ada") },
      { follower: makeProfileRow("maya") }
    ];

    const profiles = mapFollowerRows(rows);

    expect(profiles.map((p) => p.username)).toEqual(["ada", "maya"]);
  });

  it("maps an empty row list to an empty array", () => {
    expect(mapFollowerRows([])).toEqual([]);
  });
});
