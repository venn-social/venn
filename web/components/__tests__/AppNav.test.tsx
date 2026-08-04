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

  it("shows Explorer as disabled rather than as a dead link", () => {
    render(<AppNav />);
    expect(screen.queryByRole("link", { name: /Explorer/ })).toBeNull();
    expect(screen.getByText("Explorer").getAttribute("aria-disabled")).toBe("true");
  });

  it("orders the tabs Feed, Explorer, Profile like the iOS tab bar", () => {
    // Explorer sits in the middle even though it isn't a link yet —
    // appending it last silently changed the running order once already.
    render(<AppNav />);
    const labels = screen
      .getAllByRole("listitem")
      .map((item) => item.textContent)
      .filter((text) => text !== "venn");
    expect(labels).toEqual(["Feed", "Explorer", "Profile", "Log"]);
  });

  it("marks the active route for assistive tech", () => {
    render(<AppNav />);
    expect(screen.getByRole("link", { name: "Feed" }).getAttribute("aria-current")).toBe("page");
    expect(screen.getByRole("link", { name: "Profile" }).getAttribute("aria-current")).toBeNull();
  });
});
