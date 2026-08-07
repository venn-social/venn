import { render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { AppNav } from "@/components/AppNav";

vi.mock("next/navigation", () => ({
  usePathname: () => "/feed",
}));

describe("AppNav", () => {
  it("links to the feed and the profile", () => {
    render(<AppNav />);
    expect(screen.getByRole("link", { name: "Feed" }).getAttribute("href")).toBe("/feed");
    expect(screen.getByRole("link", { name: "Profile" }).getAttribute("href")).toBe("/profile");
  });

  it("links Explorer now that the route exists", () => {
    render(<AppNav />);
    expect(screen.getByRole("link", { name: "Explorer" }).getAttribute("href")).toBe("/explorer");
  });

  it("orders the tabs like the iOS tab bar", () => {
    // Order is load-bearing: appending a tab last silently changed the
    // running order once already.
    render(<AppNav />);
    const labels = screen
      .getAllByRole("listitem")
      .map((item) => item.textContent)
      .filter((text) => text !== "venn");
    // The compose action is an icon now, so it contributes no text — it is
    // asserted by its accessible name below instead.
    // Lists and Activity moved into the side menu; the trailing two empty
    // strings are the icon-only compose action and the menu toggle.
    expect(labels).toEqual(["Feed", "Explorer", "Profile", "", ""]);
  });

  it("marks the active route for assistive tech", () => {
    render(<AppNav />);
    expect(screen.getByRole("link", { name: "Feed" }).getAttribute("aria-current")).toBe("page");
    expect(screen.getByRole("link", { name: "Profile" }).getAttribute("aria-current")).toBeNull();
  });

  it("keeps the compose action reachable as an icon-only button", () => {
    render(<AppNav />);
    expect(screen.getByRole("link", { name: "Log" }).getAttribute("href")).toBe("/composer");
  });

  it("no longer offers Lists or Activity as tabs", () => {
    // They live in the side menu now, and only there.
    render(<AppNav />);
    expect(screen.queryByRole("link", { name: "Lists" })).toBeNull();
    expect(screen.queryByRole("link", { name: "Activity" })).toBeNull();
  });

  it("hands the unread count to the menu toggle", () => {
    render(<AppNav unreadCount={3} />);
    expect(screen.getByRole("button", { name: "More, 3 unread" })).toBeTruthy();
  });
});
