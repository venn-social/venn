import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { SideMenu } from "@/components/SideMenu";

vi.mock("next/navigation", () => ({
  usePathname: () => "/feed"
}));

/** The panel is closed until the toggle is pressed. */
function open() {
  fireEvent.click(screen.getByRole("button", { name: /More/ }));
}

describe("SideMenu", () => {
  it("stays closed until asked", () => {
    render(<SideMenu />);
    expect(screen.queryByRole("link", { name: "Settings" })).toBeNull();
    expect(screen.getByRole("button", { name: "More" }).getAttribute("aria-expanded")).toBe(
      "false"
    );
  });

  it("holds exactly the four secondary surfaces, in order", () => {
    // Order is load-bearing — it was set deliberately, and appending to the
    // array is the easy way to change it by accident.
    render(<SideMenu />);
    open();
    const labels = screen.getAllByRole("link").map((link) => link.textContent);
    expect(labels).toEqual(["Settings", "Lists", "Activity", "Year in Review"]);
  });

  it("points each entry at its route", () => {
    render(<SideMenu />);
    open();
    expect(screen.getByRole("link", { name: "Settings" }).getAttribute("href")).toBe("/settings");
    expect(screen.getByRole("link", { name: "Lists" }).getAttribute("href")).toBe("/lists");
    expect(screen.getByRole("link", { name: /Activity/ }).getAttribute("href")).toBe(
      "/notifications"
    );
    expect(screen.getByRole("link", { name: "Year in Review" }).getAttribute("href")).toBe(
      "/profile/year"
    );
  });

  it("announces the unread count on the toggle so it is visible while closed", () => {
    // The whole point of a badge is to be seen before you open anything.
    render(<SideMenu unreadCount={3} />);
    expect(screen.getByRole("button", { name: "More, 3 unread" })).toBeTruthy();
  });

  it("badges Activity inside the panel too", () => {
    render(<SideMenu unreadCount={3} />);
    open();
    expect(screen.getByRole("link", { name: /Activity/ }).textContent).toContain("3");
  });

  it("caps the visible badge rather than letting it stretch the row", () => {
    render(<SideMenu unreadCount={42} />);
    open();
    expect(screen.getByRole("link", { name: /Activity/ }).textContent).toContain("9+");
  });

  it("announces the exact count even when the badge is capped", () => {
    render(<SideMenu unreadCount={42} />);
    expect(screen.getByRole("button", { name: "More, 42 unread" })).toBeTruthy();
  });

  it("closes when an entry is chosen", () => {
    // Leaving the panel open over the page you just asked for means every
    // visit starts with a dismissal.
    render(<SideMenu />);
    open();
    fireEvent.click(screen.getByRole("link", { name: "Settings" }));
    expect(screen.queryByRole("link", { name: "Settings" })).toBeNull();
  });

  it("toggles shut when the control is pressed again", () => {
    render(<SideMenu />);
    open();
    expect(screen.getByRole("link", { name: "Settings" })).toBeTruthy();
    open();
    expect(screen.queryByRole("link", { name: "Settings" })).toBeNull();
  });
});
