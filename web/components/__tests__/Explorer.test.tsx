import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Explorer } from "@/components/Explorer";

const push = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ push }) }));
vi.mock("@/lib/supabase/client", () => ({ createClient: () => ({}) }));

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
    fireEvent.click(screen.getByRole("button", { name: "People" }));
    expect(screen.getByText("Find your people")).toBeDefined();
  });

  it("finds people and links each to their profile", async () => {
    render(<Explorer />);
    fireEvent.click(screen.getByRole("button", { name: "People" }));
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), { target: { value: "maya" } });

    const link = await screen.findByRole("link", { name: /Maya Okonkwo/ });
    expect(link.getAttribute("href")).toBe("/maya");
  });

  it("says so when nobody matches", async () => {
    searchProfiles.mockResolvedValue([]);
    render(<Explorer />);
    fireEvent.click(screen.getByRole("button", { name: "People" }));
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), { target: { value: "zzz" } });

    expect(await screen.findByText("No one found")).toBeDefined();
  });

  it("sends a picked media result to the composer with a prefill", async () => {
    render(<Explorer />);
    fireEvent.change(screen.getByPlaceholderText(/Search movies/), {
      target: { value: "past lives" }
    });

    fireEvent.click(await screen.findByRole("button", { name: /Past Lives/ }));

    await waitFor(() => expect(push).toHaveBeenCalled());
    expect(push.mock.calls[0][0]).toBe("/composer?kind=movie&q=Past+Lives");
  });

  it("shows the empty-catalog state when a category has nothing to browse", async () => {
    render(<Explorer />);
    fireEvent.click(screen.getByRole("button", { name: "Movies" }));
    expect(await screen.findByText("Nothing here yet")).toBeDefined();
  });
});
