import { fireEvent, render, screen, waitFor } from "@testing-library/react";
import { beforeEach, describe, expect, it, vi } from "vitest";
import { Composer } from "@/components/Composer";

vi.mock("@/lib/supabase/client", () => ({ createClient: () => ({}) }));
vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), refresh: vi.fn() })
}));

const { upsertMedia, createPost } = vi.hoisted(() => ({
  upsertMedia: vi.fn(),
  createPost: vi.fn()
}));

vi.mock("@/lib/compose", async () => {
  const actual = await vi.importActual<typeof import("@/lib/compose")>("@/lib/compose");
  return { ...actual, upsertMedia, createPost };
});

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
  upsertMedia.mockReset().mockResolvedValue("media-1");
  createPost.mockReset().mockResolvedValue(undefined);
  vi.stubGlobal(
    "fetch",
    vi.fn(async () => ({ ok: true, json: async () => ({ candidates: [candidate] }) }))
  );
});

async function pickTheMovie() {
  fireEvent.change(screen.getByPlaceholderText("Search"), { target: { value: "past lives" } });
  fireEvent.click(await screen.findByRole("button", { name: /Past Lives/ }));
}

describe("Composer", () => {
  it("shows results for a query and lets one be picked", async () => {
    render(<Composer userId="u1" />);
    await pickTheMovie();
    expect(await screen.findByRole("button", { name: "Log it" })).toBeDefined();
  });

  it("logs a rated post when a sentiment is chosen", async () => {
    render(<Composer userId="u1" />);
    await pickTheMovie();

    fireEvent.click(screen.getByRole("button", { name: /Love/ }));
    fireEvent.click(screen.getByRole("button", { name: "Log it" }));

    await waitFor(() => expect(createPost).toHaveBeenCalled());
    expect(createPost.mock.calls[0][1]).toMatchObject({ action: "rated", rating: 5 });
  });

  it("logs a plain post when no sentiment is chosen", async () => {
    render(<Composer userId="u1" />);
    await pickTheMovie();

    fireEvent.click(screen.getByRole("button", { name: "Log it" }));

    await waitFor(() => expect(createPost).toHaveBeenCalled());
    expect(createPost.mock.calls[0][1]).toMatchObject({ action: "logged", rating: null });
  });

  it("saves to the watchlist without a rating or caption", async () => {
    render(<Composer userId="u1" />);
    await pickTheMovie();

    fireEvent.click(screen.getByRole("button", { name: "Add to watchlist" }));

    await waitFor(() => expect(createPost).toHaveBeenCalled());
    expect(createPost.mock.calls[0][1]).toMatchObject({
      action: "saved",
      rating: null,
      caption: null
    });
  });

  it("surfaces the rate-limit message distinctly from a generic failure", async () => {
    // The posts trigger raises P0429; waiting actually helps, so the copy
    // should say so rather than "try again".
    createPost.mockRejectedValue({ code: "P0429" });
    render(<Composer userId="u1" />);
    await pickTheMovie();

    fireEvent.click(screen.getByRole("button", { name: "Log it" }));

    expect(await screen.findByText(/logging very fast/)).toBeDefined();
  });
});
