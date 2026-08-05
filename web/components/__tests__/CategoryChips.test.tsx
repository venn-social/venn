import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { browseKindFor, CategoryChips, searchKindsFor } from "@/components/CategoryChips";

describe("category mapping", () => {
  it("searches every media kind for All", () => {
    expect(searchKindsFor("all")).toEqual(["movie", "show", "album", "book"]);
  });

  it("searches no media kinds for People", () => {
    // People search goes through profiles, not the media catalog.
    expect(searchKindsFor("people")).toEqual([]);
  });

  it("maps each media category to its one kind", () => {
    expect(searchKindsFor("movies")).toEqual(["movie"]);
    expect(searchKindsFor("tv")).toEqual(["show"]);
    expect(searchKindsFor("music")).toEqual(["album"]);
    expect(searchKindsFor("books")).toEqual(["book"]);
  });

  it("has no browse kind for All or People", () => {
    expect(browseKindFor("all")).toBeNull();
    expect(browseKindFor("people")).toBeNull();
  });

  it("browses the matching kind for media categories", () => {
    expect(browseKindFor("movies")).toBe("movie");
    expect(browseKindFor("tv")).toBe("show");
  });
});

describe("CategoryChips", () => {
  it("renders all six categories with iOS's titles", () => {
    render(<CategoryChips value="all" onChange={() => {}} />);
    for (const label of ["All", "People", "Movies", "TV", "Music", "Books"]) {
      expect(screen.getByRole("button", { name: label })).toBeDefined();
    }
  });

  it("reports the selected category", () => {
    const onChange = vi.fn();
    render(<CategoryChips value="all" onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", { name: "People" }));
    expect(onChange).toHaveBeenCalledWith("people");
  });

  it("marks the current category as pressed", () => {
    render(<CategoryChips value="books" onChange={() => {}} />);
    expect(screen.getByRole("button", { name: "Books" }).getAttribute("aria-pressed")).toBe("true");
    expect(screen.getByRole("button", { name: "All" }).getAttribute("aria-pressed")).toBe("false");
  });
});
