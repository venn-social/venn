import { render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { FeedPagination } from "@/components/FeedPagination";
import type { FeedPost } from "@/lib/feed";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ refresh: vi.fn() })
}));

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({})
}));

const { fetchFeedPage } = vi.hoisted(() => ({ fetchFeedPage: vi.fn() }));

vi.mock("@/lib/feed", async () => {
  const actual = await vi.importActual<typeof import("@/lib/feed")>("@/lib/feed");
  return { ...actual, fetchFeedPage };
});

// The sentinel drives loading via IntersectionObserver, which jsdom does
// not implement. This stub fires "it's visible" as soon as anything is
// observed, which is exactly the condition the component reacts to.
const observers: (() => void)[] = [];

beforeEach(() => {
  observers.length = 0;
  fetchFeedPage.mockReset();

  vi.stubGlobal(
    "IntersectionObserver",
    class {
      constructor(private callback: IntersectionObserverCallback) {}
      observe() {
        observers.push(() =>
          this.callback([{ isIntersecting: true } as IntersectionObserverEntry], this as never)
        );
        observers[observers.length - 1]();
      }
      disconnect() {}
      unobserve() {}
    }
  );
});

function post(id: string, createdAt: string): FeedPost {
  return {
    id,
    action: "logged",
    rating: null,
    caption: null,
    createdAt: new Date(createdAt),
    media: {
      id: `m-${id}`,
      kind: "movie",
      title: `Film ${id}`,
      year: 2023,
      primaryCreator: null,
      // With a cover, the title renders once (the heading). Without one,
      // FeedRow also prints it inside the cover placeholder, so a plain
      // getByText would match twice.
      coverUrl: `https://example.test/${id}.jpg`,
      externalSource: "tmdb" as const,
      externalId: id
    },
    author: {
      id: "u1",
      username: "ada",
      displayName: "Ada",
      avatarUrl: null,
      bio: null,
      isPrivate: false,
    language: "en" as const,
      createdAt: "2026-01-01T00:00:00Z"
    }
  };
}

describe("FeedPagination", () => {
  it("appends the next page when the sentinel comes into view", async () => {
    fetchFeedPage.mockResolvedValue([post("2", "2026-07-31T10:00:00Z")]);

    render(<FeedPagination initialCursor="2026-08-01T10:00:00Z" initialHasMore={true} />);

    expect(await screen.findByText("Film 2")).toBeDefined();
  });

  it("asks for posts strictly older than the cursor it was given", async () => {
    fetchFeedPage.mockResolvedValue([post("2", "2026-07-31T10:00:00Z")]);

    render(<FeedPagination initialCursor="2026-08-01T10:00:00Z" initialHasMore={true} />);

    await waitFor(() => expect(fetchFeedPage).toHaveBeenCalled());
    const [, options] = fetchFeedPage.mock.calls[0];
    expect(options.before).toEqual(new Date("2026-08-01T10:00:00Z"));
  });

  it("does not fetch at all when the first page already exhausted the feed", () => {
    render(<FeedPagination initialCursor="2026-08-01T10:00:00Z" initialHasMore={false} />);
    expect(fetchFeedPage).not.toHaveBeenCalled();
  });

  it("stops paging after a short page rather than looping forever", async () => {
    // One row back is fewer than FEED_PAGE_SIZE, so there is no more feed.
    fetchFeedPage.mockResolvedValue([post("2", "2026-07-31T10:00:00Z")]);

    render(<FeedPagination initialCursor="2026-08-01T10:00:00Z" initialHasMore={true} />);

    await screen.findByText("Film 2");
    await waitFor(() => expect(fetchFeedPage).toHaveBeenCalledTimes(1));
  });

  it("offers a retry when a page fails instead of failing silently", async () => {
    fetchFeedPage.mockRejectedValue(new Error("network"));

    render(<FeedPagination initialCursor="2026-08-01T10:00:00Z" initialHasMore={true} />);

    expect(await screen.findByRole("button", { name: /Try again/ })).toBeDefined();
  });
});
