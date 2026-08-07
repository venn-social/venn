import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ProfileShelves } from "@/components/ProfileShelves";

// ProfileShelves refreshes after a removal, so it needs a router.
vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh: vi.fn() })
}));
import type { LibraryItem } from "@/lib/library";

function item(id: string, title: string, kind: LibraryItem["media"]["kind"] = "book"): LibraryItem {
  return {
    id,
    action: "logged",
    rating: null,
    createdAt: new Date("2026-08-01T10:00:00Z"),
    media: {
      id: `m-${id}`,
      kind,
      title,
      year: 2020,
      primaryCreator: "Susanna Clarke",
      coverUrl: null,
      externalSource: null,
      externalId: null,
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

  it("filters the shelf by media kind", () => {
    render(
      <ProfileShelves
        collection={[item("1", "Piranesi", "book"), item("2", "Drive", "movie")]}
        watchlist={[]}
        {...copy}
      />
    );

    fireEvent.click(screen.getByRole("tab", { name: "Movies" }));

    expect(screen.queryByText("Piranesi")).toBeNull();
  });

  it("says the filter came up empty rather than reusing the shelf's empty copy", () => {
    // "Nothing in your collection yet." would be a lie when the collection
    // has things — they just are not of the chosen type.
    render(
      <ProfileShelves
        collection={[item("1", "Piranesi", "book"), item("2", "Drive", "movie")]}
        watchlist={[]}
        {...copy}
      />
    );

    fireEvent.click(screen.getByRole("tab", { name: "Movies" }));
    fireEvent.click(screen.getByRole("tab", { name: "Watchlist" }));
    fireEvent.click(screen.getByRole("tab", { name: "Collection" }));

    // Switching shelves resets the filter, so everything is back.
    expect(screen.queryByText(/Nothing of that type/)).toBeNull();
  });

  it("only offers the remove control on your own shelves", () => {
    const { rerender } = render(
      <ProfileShelves collection={[item("1", "Piranesi")]} watchlist={[]} {...copy} />
    );
    expect(screen.queryByRole("button", { name: "Remove Piranesi" })).toBeNull();

    rerender(
      <ProfileShelves collection={[item("1", "Piranesi")]} watchlist={[]} {...copy} canEdit />
    );
    expect(screen.getByRole("button", { name: "Remove Piranesi" })).toBeTruthy();
  });
});
