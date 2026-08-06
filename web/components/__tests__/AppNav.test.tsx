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
    expect(labels).toEqual(["Feed", "Explorer", "Lists", "Activity", "Profile", ""]);
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

  it("shows no badge when there is nothing unread", () => {
    render(<AppNav />);
    expect(screen.getByRole("link", { name: "Activity" }).textContent).toBe("Activity");
  });

  it("badges Activity with the unread count", () => {
    render(<AppNav unreadCount={3} />);
    // The link is labelled with the real number, because the visible
    // badge caps at "9+" and would otherwise under-report it.
    expect(screen.getByRole("link", { name: "Activity, 3 unread" })).toBeTruthy();
  });

  it("caps the badge rather than letting it stretch the nav", () => {
    render(<AppNav unreadCount={42} />);
    const activity = screen.getByRole("link", { name: /Activity/ });
    expect(activity.textContent).toContain("9+");
  });

  it("announces the exact count even when the badge is capped", () => {
    render(<AppNav unreadCount={42} />);
    expect(screen.getByRole("link", { name: "Activity, 42 unread" })).toBeTruthy();
  });
});
