import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { ProfileShelves } from "@/components/ProfileShelves";
import type { LibraryItem } from "@/lib/library";

function item(id: string, title: string): LibraryItem {
  return {
    id,
    action: "logged",
    rating: null,
    createdAt: new Date("2026-08-01T10:00:00Z"),
    media: {
      id: `m-${id}`,
      kind: "book",
      title,
      year: 2020,
      primaryCreator: "Susanna Clarke",
      coverUrl: null,
    },
  };
}

const copy = {
  emptyCollection: "Nothing in your collection yet.",
  emptyWatchlist: "Your watchlist is empty.",
};

describe("ProfileShelves", () => {
  it("shows the collection first", () => {
    render(<ProfileShelves collection={[item("1", "Piranesi")]} watchlist={[]} {...copy} />);
    expect(screen.getByText("Piranesi")).toBeDefined();
    expect(screen.getByRole("tab", { name: "Collection" }).getAttribute("aria-selected")).toBe(
      "true"
    );
  });

  it("switches to the watchlist when its tab is clicked", () => {
    render(
      <ProfileShelves
        collection={[item("1", "Piranesi")]}
        watchlist={[item("2", "Babel")]}
        {...copy}
      />
    );

    fireEvent.click(screen.getByRole("tab", { name: "Watchlist" }));

    expect(screen.getByText("Babel")).toBeDefined();
    expect(screen.queryByText("Piranesi")).toBeNull();
  });

  it("shows the collection's empty copy when it has nothing", () => {
    render(<ProfileShelves collection={[]} watchlist={[item("2", "Babel")]} {...copy} />);
    expect(screen.getByText("Nothing in your collection yet.")).toBeDefined();
  });

  it("shows the watchlist's own empty copy, not the collection's", () => {
    render(<ProfileShelves collection={[item("1", "Piranesi")]} watchlist={[]} {...copy} />);

    fireEvent.click(screen.getByRole("tab", { name: "Watchlist" }));

    expect(screen.getByText("Your watchlist is empty.")).toBeDefined();
    expect(screen.queryByText("Nothing in your collection yet.")).toBeNull();
  });
});
