import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Explorer } from "@/components/Explorer";

const push = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push }) }));
vi.mock("@/lib/supabase/client", () => ({ createClient: () => ({}) }));
vi.mock("@/lib/compose", () => ({ upsertMedia: async () => "media-uuid" }));

function shelfOf(title: string, kind: "movie" | "book") {
  return {
    source: "trending" as const,
    seedTitle: null,
    items: [
      {
        kind: "candidate" as const,
        candidate: {
          id: `tmdb:${kind}:${title}`,
          title,
          primaryCreator: null,
          year: null,
          coverUrl: null,
          overview: null,
          externalId: title,
          externalSource: "tmdb" as const,
          kind
        }
      }
    ]
  };
}

// One shelf holding both kinds, which is what the real feed produces and
// what the per-kind filter actually has to cope with.
const mixedShelf = {
  ...shelfOf("A Film", "movie"),
  items: [...shelfOf("A Film", "movie").items, ...shelfOf("A Book", "book").items]
};

const { searchProfiles, fetchRecentMedia } = vi.hoisted(() => ({
  searchProfiles: vi.fn(),
  fetchRecentMedia: vi.fn()
}));

vi.mock("@/lib/people", async () => {
  const actual = await vi.importActual<typeof import("@/lib/people")>("@/lib/people");
  return { ...actual, searchProfiles };
});
vi.mock("@/lib/explore", async () => {
  const actual = await vi.importActual<typeof import("@/lib/explore")>("@/lib/explore");
  return { ...actual, fetchRecentMedia };
});

const person = {
  id: "u2",
  username: "maya",
  displayName: "Maya Okonkwo",
  avatarUrl: null,
  bio: null,
  isPrivate: false,
  createdAt: "2026-01-01T00:00:00Z"
};

const candidate = {
  id: "tmdb:1",
  title: "Past Lives",
  primaryCreator: "Celine Song",
  year: 2023,
  coverUrl: null,
  overview: null,
  externalId: "1",
  externalSource: "tmdb" as const,
  kind: "movie" as const
};

beforeEach(() => {
  push.mockReset();
  searchProfiles.mockReset().mockResolvedValue([person]);
  fetchRecentMedia.mockReset().mockResolvedValue([]);
  // One result per kind, as the real endpoint returns — the All category
  // fans out to four kinds in parallel.
  vi.stubGlobal(
    "fetch",
    vi.fn(async (url: string) => {
      const kind = new URL(url, "http://localhost").searchParams.get("kind");
      return {
        ok: true,
        json: async () => ({
          candidates: kind === "movie" ? [candidate] : []
        })
      };
    })
  );
});

describe("Explorer", () => {
  it("prompts for a search before anything is typed", () => {
    render(<Explorer />);
    expect(screen.getByText("Search everything")).toBeDefined();
  });

  it("shows the People prompt when that category is selected", () => {
    render(<Explorer />);
    fireEvent.click(screen.getByRole("tab", { name: "People" }));
    expect(screen.getByText("Find your people")).toBeDefined();
  });

  it("finds people and links each to their profile", async () => {
    render(<Explorer />);
    fireEvent.click(screen.getByRole("tab", { name: "People" }));
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), { target: { value: "maya" } });

    const link = await screen.findByRole("link", { name: /Maya Okonkwo/ });
    expect(link.getAttribute("href")).toBe("/maya");
  });

  it("says so when nobody matches", async () => {
    searchProfiles.mockResolvedValue([]);
    render(<Explorer />);
    fireEvent.click(screen.getByRole("tab", { name: "People" }));
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), { target: { value: "zzz" } });

    expect(await screen.findByText("No one found")).toBeDefined();
  });

  it("opens a picked search result on its detail page", async () => {
    // It used to push /composer?q=<title>, which re-ran the search you had
    // just done and made you pick the same thing again to read about it.
    render(<Explorer />);
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), {
      target: { value: "past lives" }
    });

    fireEvent.click(await screen.findByRole("button", { name: /Past Lives/ }));

    await waitFor(() => expect(push).toHaveBeenCalled());
    expect(push.mock.calls[0][0]).toBe("/media/media-uuid");
  });

  it("never shows Recently added, whatever the catalog holds", async () => {
    // Per-kind tabs listed the newest rows in the catalog — what other
    // people happened to log, which belongs on a profile page.
    render(<Explorer />);
    fireEvent.click(screen.getByRole("tab", { name: "Movies" }));

    expect(await screen.findByText("No recommendations yet")).toBeDefined();
    expect(screen.queryByText("Recently added")).toBeNull();
  });

  it("shows the shelves for the kind chosen, and only those", async () => {
    render(<Explorer shelves={[mixedShelf]} />);
    fireEvent.click(screen.getByRole("tab", { name: "Books" }));

    expect(await screen.findByText("Trending this week")).toBeDefined();
    // The title appears twice per card — as the cover placeholder and as
    // the caption — so count cards, not text nodes.
    expect(screen.getAllByText("A Book").length).toBeGreaterThan(0);
    expect(screen.queryByText("A Film")).toBeNull();
  });
});
