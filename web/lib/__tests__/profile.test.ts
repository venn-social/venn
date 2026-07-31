import { describe, expect, it } from "vitest";
import { toUserProfile, type ProfileRow } from "@/lib/profile";

/**
 * Pins the `profiles` row shape, same spirit as
 * ios/VennTests/Models/UserProfileTests.swift — this is the wire format
 * `fetchProfile` maps into the app's `UserProfile` domain type.
 */
describe("toUserProfile", () => {
  it("maps a full row", () => {
    const row: ProfileRow = {
      id: "99999999-9999-9999-9999-999999999999",
      username: "venn",
      display_name: "Venn",
      avatar_url: null,
      bio: "The official venn account.",
      is_private: false,
      created_at: "2026-06-12T17:31:27.999742+00:00",
    };

    expect(toUserProfile(row)).toEqual({
      id: "99999999-9999-9999-9999-999999999999",
      username: "venn",
      displayName: "Venn",
      avatarUrl: null,
      bio: "The official venn account.",
      isPrivate: false,
      createdAt: "2026-06-12T17:31:27.999742+00:00",
    });
  });

  it("maps a row with nullable fields absent", () => {
    const row: ProfileRow = {
      id: "11111111-1111-1111-1111-111111111111",
      username: "maya",
      display_name: null,
      avatar_url: null,
      bio: null,
      is_private: true,
      created_at: "2026-05-01T00:00:00Z",
    };

    const profile = toUserProfile(row);
    expect(profile.displayName).toBeNull();
    expect(profile.bio).toBeNull();
    expect(profile.isPrivate).toBe(true);
  });
});
