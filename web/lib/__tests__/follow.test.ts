import { describe, expect, it } from "vitest";
import {
  mapFollowerRows,
  mapFollowingRows,
  type FollowerRow,
  type FollowingRow
} from "@/lib/follow";
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

describe("mapFollowingRows", () => {
  it("reads the followee side of the edge, not the follower side", () => {
    // The two lists query the same table from opposite ends — mixing the
    // embedded key up would silently show the wrong people.
    const rows: FollowingRow[] = [
      { followee: makeProfileRow("ada") },
      { followee: makeProfileRow("maya") }
    ];

    expect(mapFollowingRows(rows).map((profile) => profile.username)).toEqual(["ada", "maya"]);
  });

  it("maps an empty list to an empty list", () => {
    expect(mapFollowingRows([])).toEqual([]);
  });
});

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
