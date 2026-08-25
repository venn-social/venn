import { render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { LaunchSplash } from "@/components/LaunchSplash";

/** jsdom has no matchMedia; every branch of the splash reads one. */
function stubMedia(matches: Record<string, boolean>) {
  vi.stubGlobal("matchMedia", (query: string) => ({
    matches: matches[query] ?? false,
    addEventListener: () => {},
    removeEventListener: () => {}
  }));
}

describe("LaunchSplash", () => {
  beforeEach(() => {
    sessionStorage.clear();
    stubMedia({});
  });

  it("plays the intro on a fresh session", () => {
    render(<LaunchSplash />);
    expect(screen.getByRole("status", { name: "Venn loading" })).toBeDefined();
  });

  it("stays out of the way once this session has seen it", () => {
    // A tab is opened and reopened all day. iOS cold starts are rare; this
    // is the departure from it that keeps the intro an intro.
    sessionStorage.setItem("venn:launch-splash-seen", "1");
    const { container } = render(<LaunchSplash />);
    expect(container.innerHTML).toBe("");
  });

  it("shows the still mark instead of the video under Reduce Motion", () => {
    stubMedia({ "(prefers-reduced-motion: reduce)": true });
    const { container } = render(<LaunchSplash />);

    expect(container.querySelector("video")).toBeNull();
    expect(container.querySelector("svg")).not.toBeNull();
  });

  it("picks the video that matches the colour scheme", () => {
    stubMedia({ "(prefers-color-scheme: dark)": true });
    const { container } = render(<LaunchSplash />);
    expect(container.querySelector("video")?.getAttribute("src")).toContain("dark");
  });

  it("uses the light video otherwise", () => {
    const { container } = render(<LaunchSplash />);
    expect(container.querySelector("video")?.getAttribute("src")).toContain("light");
  });
});
