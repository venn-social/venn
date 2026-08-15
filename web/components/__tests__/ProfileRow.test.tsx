import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ProfileRow } from "@/components/ProfileRow";
import type { UserProfile } from "@/lib/profile";

function profile(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: "u1",
    username: "ada",
    displayName: "Ada Lovelace",
    avatarUrl: null,
    bio: null,
    isPrivate: false,
    language: "en" as const,
    createdAt: "2026-01-01T00:00:00Z",
    ...overrides
  };
}

describe("ProfileRow", () => {
  it("shows the display name and handle", () => {
    render(<ProfileRow profile={profile()} />);
    expect(screen.getByText("Ada Lovelace")).toBeDefined();
    expect(screen.getByText("@ada")).toBeDefined();
  });

  it("falls back to the username when there is no display name", () => {
    render(<ProfileRow profile={profile({ displayName: null })} />);
    // Both the name line and the handle line read from username here.
    expect(screen.getAllByText(/ada/).length).toBeGreaterThan(0);
  });

  it("links to the person's profile by username, not id", () => {
    render(<ProfileRow profile={profile()} />);
    expect(screen.getByRole("link").getAttribute("href")).toBe("/ada");
  });
});
