import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { MediaOverflowMenu } from "@/components/MediaOverflowMenu";

describe("MediaOverflowMenu", () => {
  it("keeps its actions hidden until opened", () => {
    render(
      <MediaOverflowMenu
        label="Options for Drive"
        actions={[{ label: "Edit", onSelect: vi.fn() }]}
      />
    );
    expect(screen.queryByRole("menuitem")).toBeNull();
    expect(
      screen.getByRole("button", { name: "Options for Drive" }).getAttribute("aria-expanded")
    ).toBe("false");
  });

  it("names itself after the artwork it belongs to", () => {
    // A grid of identical "More" buttons is unusable with a screen reader.
    render(<MediaOverflowMenu label="Options for Drive" actions={[]} />);
    expect(screen.getByRole("button", { name: "Options for Drive" })).toBeTruthy();
  });

  it("shows glyphs instead of words in the icons presentation", () => {
    const onSelect = vi.fn();
    render(
      <MediaOverflowMenu
        label="Options"
        presentation="icons"
        actions={[{ label: "Log", icon: <svg data-testid="tick" />, onSelect }]}
      />
    );
    fireEvent.click(screen.getByRole("button", { name: "Options" }));

    // The word is gone from the screen but not from the accessible name:
    // a glyph nobody can name is a glyph nobody can use.
    const item = screen.getByRole("menuitem", { name: "Log" });
    expect(item.textContent).toBe("");
    expect(screen.getByTestId("tick")).toBeTruthy();

    fireEvent.click(item);
    expect(onSelect).toHaveBeenCalledOnce();
  });

  it("runs the chosen action and closes", () => {
    const onSelect = vi.fn();
    render(<MediaOverflowMenu label="Options" actions={[{ label: "Remove", onSelect }]} />);

    fireEvent.click(screen.getByRole("button", { name: "Options" }));
    fireEvent.click(screen.getByRole("menuitem", { name: "Remove" }));

    expect(onSelect).toHaveBeenCalledOnce();
    expect(screen.queryByRole("menuitem")).toBeNull();
  });

  it("stays reachable without hover", () => {
    // The trigger is revealed by group-hover, which never fires on touch;
    // the hover-none variant is what keeps it usable on a phone.
    render(<MediaOverflowMenu label="Options" actions={[]} />);
    expect(screen.getByRole("button", { name: "Options" }).className).toContain(
      "hover-none:opacity-100"
    );
  });

  it("disables the trigger while an action is in flight", () => {
    render(<MediaOverflowMenu label="Options" actions={[]} busy />);
    expect(screen.getByRole("button", { name: "Options" }).hasAttribute("disabled")).toBe(true);
  });

  it("toggles shut when pressed again", () => {
    render(<MediaOverflowMenu label="Options" actions={[{ label: "Edit", onSelect: vi.fn() }]} />);
    const trigger = screen.getByRole("button", { name: "Options" });

    fireEvent.click(trigger);
    expect(screen.getByRole("menuitem", { name: "Edit" })).toBeTruthy();

    fireEvent.click(trigger);
    expect(screen.queryByRole("menuitem")).toBeNull();
  });
});
