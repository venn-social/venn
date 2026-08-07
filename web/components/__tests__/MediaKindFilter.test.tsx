import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { MediaKindFilter } from "@/components/MediaKindFilter";
import type { MediaKind } from "@/lib/media";

function available(...kinds: MediaKind[]) {
  return new Set<MediaKind>(kinds);
}

describe("MediaKindFilter", () => {
  it("offers All plus every kind present", () => {
    render(
      <MediaKindFilter selected={null} onSelect={vi.fn()} available={available("movie", "book")} />
    );
    expect(screen.getAllByRole("tab").map((tab) => tab.textContent)).toEqual([
      "All",
      "Movies",
      "Books"
    ]);
  });

  it("keeps the shared order rather than the order kinds happened to appear", () => {
    render(
      <MediaKindFilter
        selected={null}
        onSelect={vi.fn()}
        available={available("album", "movie", "show")}
      />
    );
    expect(screen.getAllByRole("tab").map((tab) => tab.textContent)).toEqual([
      "All",
      "Movies",
      "Shows",
      "Albums"
    ]);
  });

  it("hides itself entirely when there is only one kind to filter", () => {
    // A row of chips that all lead to the same grid is noise.
    const { container } = render(
      <MediaKindFilter selected={null} onSelect={vi.fn()} available={available("movie")} />
    );
    expect(container.firstChild).toBeNull();
  });

  it("hides itself when the shelf is empty", () => {
    const { container } = render(
      <MediaKindFilter selected={null} onSelect={vi.fn()} available={available()} />
    );
    expect(container.firstChild).toBeNull();
  });

  it("never offers a kind that would show an empty grid", () => {
    render(
      <MediaKindFilter selected={null} onSelect={vi.fn()} available={available("movie", "show")} />
    );
    expect(screen.queryByRole("tab", { name: "Books" })).toBeNull();
    expect(screen.queryByRole("tab", { name: "Albums" })).toBeNull();
  });

  it("marks the active chip for assistive tech", () => {
    render(
      <MediaKindFilter
        selected="movie"
        onSelect={vi.fn()}
        available={available("movie", "book")}
      />
    );
    expect(screen.getByRole("tab", { name: "Movies" }).getAttribute("aria-selected")).toBe("true");
    expect(screen.getByRole("tab", { name: "All" }).getAttribute("aria-selected")).toBe("false");
  });

  it("reports the chosen kind, and null for All", () => {
    const onSelect = vi.fn();
    render(
      <MediaKindFilter selected="movie" onSelect={onSelect} available={available("movie", "book")} />
    );

    fireEvent.click(screen.getByRole("tab", { name: "Books" }));
    expect(onSelect).toHaveBeenCalledWith("book");

    fireEvent.click(screen.getByRole("tab", { name: "All" }));
    expect(onSelect).toHaveBeenCalledWith(null);
  });
});
