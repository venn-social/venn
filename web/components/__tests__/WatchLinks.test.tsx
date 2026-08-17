import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { WatchLinks } from "@/components/WatchLinks";
import type { WatchLink } from "@/lib/catalog/detail";

function link(overrides: Partial<WatchLink> = {}): WatchLink {
  return {
    provider: "Netflix",
    kind: "stream",
    url: "https://www.netflix.com/search?q=Her",
    logoUrl: null,
    ...overrides
  };
}

describe("WatchLinks", () => {
  it("names the region for screen media, because rights are regional", () => {
    render(<WatchLinks links={[link()]} region="GB" kind="movie" />);

    expect(screen.getByRole("heading").textContent).toBe("Where to watch in United Kingdom");
    expect(screen.getByRole("link").getAttribute("href")).toBe(
      "https://www.netflix.com/search?q=Her"
    );
  });

  it("shows a book, which it used to refuse to render", () => {
    // The section was screen-only while TMDB was the only source of
    // availability. Books and albums now carry search links instead.
    render(
      <WatchLinks links={[link({ provider: "Kindle", kind: "buy" })]} region="GB" kind="book" />
    );

    expect(screen.getByRole("heading").textContent).toBe("Where to read");
  });

  it("shows an album", () => {
    render(<WatchLinks links={[link({ provider: "Spotify" })]} region="GB" kind="album" />);

    expect(screen.getByRole("heading").textContent).toBe("Where to listen");
  });

  it("does not claim a book is stocked, only that it can search", () => {
    // The screen list is an availability claim; this one is not, and the
    // copy has to keep them apart.
    render(<WatchLinks links={[link({ provider: "Kindle" })]} region="GB" kind="book" />);

    expect(screen.getByText(/can't tell whether it's stocked/i)).toBeTruthy();
    expect(screen.queryByText(/Availability from TMDB/i)).toBeNull();
  });

  it("says Find rather than Watch for a bare book link", () => {
    render(
      <WatchLinks links={[link({ provider: "Google Books", kind: "link" })]} region="GB" kind="book" />
    );

    expect(screen.getByRole("link").getAttribute("aria-label")).toBe("Find on Google Books");
  });

  it("renders an unlinked chip when we have no URL for the provider", () => {
    render(
      <WatchLinks links={[link({ provider: "Rakuten TV", url: null })]} region="GB" kind="movie" />
    );

    expect(screen.getByText("Rakuten TV")).toBeTruthy();
    expect(screen.queryByRole("link")).toBeNull();
  });

  it("renders nothing when there is nowhere to send anyone", () => {
    const { container } = render(<WatchLinks links={[]} region="GB" kind="movie" />);

    expect(container.innerHTML).toBe("");
  });
});
