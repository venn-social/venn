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

  it("only offers the options menu on your own shelves", () => {
    const { rerender } = render(
      <ProfileShelves collection={[item("1", "Piranesi")]} watchlist={[]} {...copy} />
    );
    expect(screen.queryByRole("button", { name: "Options for Piranesi" })).toBeNull();

    rerender(
      <ProfileShelves collection={[item("1", "Piranesi")]} watchlist={[]} {...copy} canEdit />
    );
    expect(screen.getByRole("button", { name: "Options for Piranesi" })).toBeTruthy();
  });

  it("keeps Edit and Remove behind the menu rather than on the artwork", () => {
    render(<ProfileShelves collection={[item("1", "Piranesi")]} watchlist={[]} {...copy} canEdit />);

    // Closed: neither action is on screen cluttering the cover.
    expect(screen.queryByRole("menuitem", { name: "Remove" })).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "Options for Piranesi" }));

    expect(screen.getByRole("menuitem", { name: "Edit" })).toBeTruthy();
    expect(screen.getByRole("menuitem", { name: "Remove" })).toBeTruthy();
  });
});

describe("the Starred tab", () => {
  const starred = [item("s1", "A Favourite", "movie")];

  it("does not exist when nothing is starred", () => {
    // A tab that is always empty is a tab that always disappoints.
    render(
      <ProfileShelves
        collection={[item("c1", "Logged", "movie")]}
        watchlist={[]}
        emptyCollection="none"
        emptyWatchlist="none"
      />
    );
    expect(screen.queryByRole("tab", { name: "Starred" })).toBeNull();
  });

  it("opens on Starred when there is one", () => {
    // A profile should lead with what someone likes, and fall back to what
    // they have seen only when they have not said.
    render(
      <ProfileShelves
        hall={starred}
        collection={[item("c1", "Logged", "movie")]}
        watchlist={[]}
        emptyCollection="none"
        emptyWatchlist="none"
      />
    );

    expect(screen.getByRole("tab", { name: "Starred" }).getAttribute("aria-selected")).toBe("true");
    expect(screen.getByText("A Favourite")).toBeDefined();
    expect(screen.queryByText("Logged")).toBeNull();
  });

  it("puts Starred first, before Collection", () => {
    render(
      <ProfileShelves
        hall={starred}
        collection={[]}
        watchlist={[]}
        emptyCollection="none"
        emptyWatchlist="none"
      />
    );
    expect(screen.getAllByRole("tab").map((t) => t.textContent)).toEqual([
      "Starred",
      "Collection",
      "Watchlist"
    ]);
  });

  it("still lets you reach the collection", () => {
    render(
      <ProfileShelves
        hall={starred}
        collection={[item("c1", "Logged", "movie")]}
        watchlist={[]}
        emptyCollection="none"
        emptyWatchlist="none"
      />
    );

    fireEvent.click(screen.getByRole("tab", { name: "Collection" }));
    expect(screen.getByText("Logged")).toBeDefined();
    expect(screen.queryByText("A Favourite")).toBeNull();
  });

  it("opens on Collection when nothing is starred", () => {
    render(
      <ProfileShelves
        collection={[item("c1", "Logged", "movie")]}
        watchlist={[]}
        emptyCollection="none"
        emptyWatchlist="none"
      />
    );
    expect(screen.getByRole("tab", { name: "Collection" }).getAttribute("aria-selected")).toBe(
      "true"
    );
  });
});

describe("reordering from the menu", () => {
  const three = [
    item("a", "First", "movie"),
    item("b", "Second", "movie"),
    item("c", "Third", "movie")
  ];

  function shelf(canEdit = true) {
    return render(
      <ProfileShelves
        collection={three}
        watchlist={[]}
        emptyCollection="none"
        emptyWatchlist="none"
        canEdit={canEdit}
      />
    );
  }

  it("offers Reorder in the menu, beside Edit and Remove", () => {
    // Dragging was invisible until you tried it, and on a grid of covers
    // it competed with the tap that opens one.
    shelf();
    fireEvent.click(screen.getByRole("button", { name: "Options for First" }));
    expect(screen.getByRole("menuitem", { name: "Reorder" })).toBeDefined();
  });

  it("does not offer it to someone looking at your profile", () => {
    shelf(false);
    expect(screen.queryByRole("button", { name: "Options for First" })).toBeNull();
  });

  it("does not offer it when there is nothing to reorder against", () => {
    render(
      <ProfileShelves
        collection={[item("a", "Only", "movie")]}
        watchlist={[]}
        emptyCollection="none"
        emptyWatchlist="none"
        canEdit
      />
    );
    fireEvent.click(screen.getByRole("button", { name: "Options for Only" }));
    expect(screen.queryByRole("menuitem", { name: "Reorder" })).toBeNull();
  });

  it("says what to do once something is held", () => {
    shelf();
    fireEvent.click(screen.getByRole("button", { name: "Options for First" }));
    fireEvent.click(screen.getByRole("menuitem", { name: "Reorder" }));
    expect(screen.getByText("Tap where it should go")).toBeDefined();
  });

  it("turns the other covers into destinations, and leaves the held one alone", () => {
    shelf();
    fireEvent.click(screen.getByRole("button", { name: "Options for First" }));
    fireEvent.click(screen.getByRole("menuitem", { name: "Reorder" }));

    expect(screen.getByRole("button", { name: /Move here, before Second/ })).toBeDefined();
    expect(screen.queryByRole("button", { name: /Move here, before First/ })).toBeNull();
  });

  it("puts it back down on Cancel", () => {
    shelf();
    fireEvent.click(screen.getByRole("button", { name: "Options for First" }));
    fireEvent.click(screen.getByRole("menuitem", { name: "Reorder" }));
    fireEvent.click(screen.getByRole("button", { name: "Cancel" }));

    expect(screen.queryByText("Tap where it should go")).toBeNull();
    expect(screen.queryByRole("button", { name: /Move here/ })).toBeNull();
  });

  it("puts it back down on Escape", () => {
    shelf();
    fireEvent.click(screen.getByRole("button", { name: "Options for First" }));
    fireEvent.click(screen.getByRole("menuitem", { name: "Reorder" }));
    fireEvent.keyDown(window, { key: "Escape" });

    expect(screen.queryByText("Tap where it should go")).toBeNull();
  });
});
