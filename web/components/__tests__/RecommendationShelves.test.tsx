import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { RecommendationShelves } from "@/components/RecommendationShelves";
import type { Shelf } from "@/lib/recommendations";

function candidateShelf(source: Shelf["source"], seedTitle: string | null): Shelf {
  return {
    source,
    seedTitle,
    items: ["1", "2", "3"].map((externalId) => ({
      kind: "candidate" as const,
      candidate: {
        id: `tmdb:movie:${externalId}`,
        title: `Title ${externalId}`,
        primaryCreator: null,
        year: null,
        coverUrl: null,
        overview: null,
        externalId,
        externalSource: "tmdb" as const,
        kind: "movie" as const
      }
    }))
  };
}

describe("RecommendationShelves", () => {
  it("names a similar shelf after the thing it is like", () => {
    render(<RecommendationShelves shelves={[candidateShelf("similar", "Past Lives")]} />);
    expect(screen.getByText("More like Past Lives")).toBeDefined();
  });

  it("labels each tier for what it actually is", () => {
    // The labels are the whole point of grouping: a trending shelf must not
    // read as a personal recommendation.
    render(
      <RecommendationShelves
        shelves={[candidateShelf("taste_twins", null), candidateShelf("trending", null)]}
      />
    );

    expect(screen.getByText("Popular with people who match your taste")).toBeDefined();
    expect(screen.getByText("Trending this week")).toBeDefined();
  });

  it("sends a catalog result to the composer, since it has no detail page yet", () => {
    render(<RecommendationShelves shelves={[candidateShelf("trending", null)]} />);
    const link = screen.getAllByRole("link")[0];

    expect(link.getAttribute("href")).toBe("/composer?kind=movie&q=Title%201");
  });

  it("renders nothing at all when there are no shelves", () => {
    const { container } = render(<RecommendationShelves shelves={[]} />);
    expect(container.firstChild).toBeNull();
  });
});
