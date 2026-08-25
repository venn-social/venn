import { fireEvent, render, screen } from "@testing-library/react";
import { beforeEach, describe, expect, it } from "vitest";
import { FeedModeShell } from "@/components/FeedModeShell";

describe("FeedModeShell", () => {
  beforeEach(() => {
    localStorage.clear();
  });

  function shell() {
    return render(
      <FeedModeShell plane={<div>the plane</div>}>
        <div>the column</div>
      </FeedModeShell>
    );
  }

  it("starts as the ordinary column", () => {
    // The plane is an option, not a replacement — a new visitor should not
    // have to work out what happened to their feed.
    shell();
    expect(screen.getByText("the column")).toBeDefined();
    expect(screen.queryByText("the plane")).toBeNull();
  });

  it("switches to the plane and back", () => {
    shell();

    fireEvent.click(screen.getByRole("button", { name: "Everywhere" }));
    expect(screen.getByText("the plane")).toBeDefined();
    expect(screen.queryByText("the column")).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "List" }));
    expect(screen.getByText("the column")).toBeDefined();
  });

  it("renders only the mode you chose, so the other is not fetching in the background", () => {
    shell();
    fireEvent.click(screen.getByRole("button", { name: "Everywhere" }));
    expect(screen.queryByText("the column")).toBeNull();
  });

  it("remembers the choice across a reload", () => {
    const first = shell();
    fireEvent.click(screen.getByRole("button", { name: "Everywhere" }));
    first.unmount();

    shell();
    expect(screen.getByText("the plane")).toBeDefined();
  });

  it("says which mode is on", () => {
    shell();
    expect(screen.getByRole("button", { name: "List" }).getAttribute("aria-pressed")).toBe("true");
    expect(screen.getByRole("button", { name: "Everywhere" }).getAttribute("aria-pressed")).toBe(
      "false"
    );
  });

  it("ignores a stored value that is not a mode", () => {
    localStorage.setItem("venn:feed-mode", "sideways");
    shell();
    expect(screen.getByText("the column")).toBeDefined();
  });
});
