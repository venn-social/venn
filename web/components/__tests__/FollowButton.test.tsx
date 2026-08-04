import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { FollowButton } from "@/components/FollowButton";

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({})
}));

// The button calls router.refresh() so the server-rendered follower counts
// and gated content re-fetch after a successful follow/unfollow.
const { refresh } = vi.hoisted(() => ({ refresh: vi.fn() }));

vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh })
}));

const { requestFollow, unfollow } = vi.hoisted(() => ({
  requestFollow: vi.fn(),
  unfollow: vi.fn()
}));

vi.mock("@/lib/follow", () => ({
  requestFollow,
  unfollow
}));

describe("FollowButton", () => {
  beforeEach(() => {
    requestFollow.mockReset();
    unfollow.mockReset();
  });

  it("starts on Follow when there is no existing status", () => {
    render(<FollowButton followerId="me" followeeId="them" initialStatus={null} />);
    expect(screen.getByRole("button", { name: "Follow" })).toBeDefined();
  });

  it("starts on Following when the initial status is accepted", () => {
    render(<FollowButton followerId="me" followeeId="them" initialStatus="accepted" />);
    expect(screen.getByRole("button", { name: "Following" })).toBeDefined();
  });

  it("starts on Requested when the initial status is pending", () => {
    render(<FollowButton followerId="me" followeeId="them" initialStatus="pending" />);
    expect(screen.getByRole("button", { name: "Requested" })).toBeDefined();
  });

  it("waits for the server before flipping Follow to Following (no optimism on follow)", async () => {
    let resolveRequest: (status: "accepted" | "pending") => void = () => {};
    requestFollow.mockReturnValue(
      new Promise((resolve) => {
        resolveRequest = resolve;
      })
    );

    render(<FollowButton followerId="me" followeeId="them" initialStatus={null} />);
    fireEvent.click(screen.getByRole("button", { name: "Follow" }));

    // Still "Follow" immediately after the click — the button doesn't
    // guess the outcome, since a private target resolves to "pending"
    // instead of "accepted".
    expect(screen.getByRole("button", { name: "Follow" })).toBeDefined();

    resolveRequest("accepted");
    await screen.findByRole("button", { name: "Following" });
  });

  it("requesting a private account lands on Requested, not Following", async () => {
    requestFollow.mockResolvedValue("pending");

    render(<FollowButton followerId="me" followeeId="them" initialStatus={null} />);
    fireEvent.click(screen.getByRole("button", { name: "Follow" }));

    await screen.findByRole("button", { name: "Requested" });
  });

  it("reverts to Follow if the follow request fails", async () => {
    requestFollow.mockRejectedValue(new Error("network"));

    render(<FollowButton followerId="me" followeeId="them" initialStatus={null} />);
    fireEvent.click(screen.getByRole("button", { name: "Follow" }));

    await screen.findByRole("button", { name: "Follow" });
  });

  it("flips Following to Follow immediately on unfollow (optimistic)", async () => {
    let resolveUnfollow: () => void = () => {};
    unfollow.mockReturnValue(
      new Promise<void>((resolve) => {
        resolveUnfollow = resolve;
      })
    );

    render(<FollowButton followerId="me" followeeId="them" initialStatus="accepted" />);
    fireEvent.click(screen.getByRole("button", { name: "Following" }));

    // Flips immediately, before the server call resolves — the optimism
    // asymmetry from FollowViewModel.swift: unfollow's outcome is never
    // in doubt, so the UI doesn't wait for it.
    expect(screen.getByRole("button", { name: "Follow" })).toBeDefined();

    resolveUnfollow();
    await vi.waitFor(() => {
      expect(unfollow).toHaveBeenCalledWith({}, "me", "them");
    });
  });

  it("reverts to Following if the unfollow call fails", async () => {
    unfollow.mockRejectedValue(new Error("network"));

    render(<FollowButton followerId="me" followeeId="them" initialStatus="accepted" />);
    fireEvent.click(screen.getByRole("button", { name: "Following" }));

    await screen.findByRole("button", { name: "Following" });
  });
});
