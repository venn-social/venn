import { render, screen, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { RecommendationShelves } from "@/components/RecommendationShelves";
import type { Shelf } from "@/lib/recommendations";

const push = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push }) }));

// Opening a catalog result creates its media row first, which is the whole
// reason it can have a detail page at all.
const upsertMedia = vi.fn(async () => "media-uuid");
vi.mock("@/lib/compose", () => ({ upsertMedia: () => upsertMedia() }));
vi.mock("@/lib/supabase/client", () => ({ createClient: () => ({}) }));

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

  it("opens a catalog result on its detail page, not on a fresh search", () => {
    // It used to link to /composer?q=<title>, which re-ran the search you
    // had just done and made you pick the same item a second time.
    render(<RecommendationShelves shelves={[candidateShelf("trending", null)]} />);

    expect(screen.queryByRole("link")).toBeNull();
    expect(screen.getAllByRole("button")[0]).toBeDefined();
  });

  it("creates the media row on the way through, then goes to it", async () => {
    render(<RecommendationShelves shelves={[candidateShelf("trending", null)]} />);
    screen.getAllByRole("button")[0].click();

    await waitFor(() => expect(push).toHaveBeenCalledWith("/media/media-uuid"));
    expect(upsertMedia).toHaveBeenCalled();
  });

  it("renders nothing at all when there are no shelves", () => {
    const { container } = render(<RecommendationShelves shelves={[]} />);
    expect(container.firstChild).toBeNull();
  });
});
