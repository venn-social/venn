import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { FeedRow } from "@/components/FeedRow";
import type { FeedPost } from "@/lib/feed";

function post(overrides: Partial<FeedPost> = {}): FeedPost {
  return {
    id: "p1",
    action: "logged",
    rating: null,
    caption: null,
    createdAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
    media: {
      id: "m1",
      kind: "movie",
      title: "Past Lives",
      year: 2023,
      primaryCreator: "Celine Song",
      coverUrl: "https://example.test/cover.jpg",
      externalSource: "tmdb" as const,
      externalId: "1"
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
    },
    ...overrides
  };
}

describe("FeedRow", () => {
  it("shows who did what, and when", () => {
    render(<FeedRow post={post()} />);
    // Name and verb are separate elements now: only the name is a link, so
    // only the name carries the accent colour that says so.
    expect(screen.getByText("Ada")).toBeDefined();
    expect(screen.getByText("logged")).toBeDefined();
    expect(screen.getByText("2h")).toBeDefined();
  });

  it("links the author's name to their profile", () => {
    render(<FeedRow post={post()} />);
    expect(screen.getByRole("link", { name: /Ada/ }).getAttribute("href")).toBe("/ada");
  });

  it("falls back to the username when there is no display name", () => {
    render(<FeedRow post={post({ author: { ...post().author, displayName: null } })} />);
    expect(screen.getByText("ada")).toBeDefined();
  });

  it("joins year and creator for the metadata line", () => {
    render(<FeedRow post={post()} />);
    expect(screen.getByText("2023 · Celine Song")).toBeDefined();
  });

  it("omits the separator when only the year is known", () => {
    const sparse = post();
    sparse.media.primaryCreator = null;
    render(<FeedRow post={sparse} />);
    expect(screen.getByText("2023")).toBeDefined();
  });

  it("shows the rating when there is one", () => {
    render(<FeedRow post={post({ rating: 4.5 })} />);
    expect(screen.getByText("4.5")).toBeDefined();
  });

  it("shows no rating when there isn't one", () => {
    render(<FeedRow post={post()} />);
    expect(screen.queryByText("4.5")).toBeNull();
  });

  it("shows the caption only when there is one", () => {
    render(<FeedRow post={post({ caption: "Devastating." })} />);
    expect(screen.getByText("Devastating.")).toBeDefined();
  });

  it("links the author to their profile", () => {
    render(<FeedRow post={post()} />);
    expect(screen.getByRole("link", { name: /Ada/ }).getAttribute("href")).toBe("/ada");
  });

  // The two social slots are in different parents on purpose. Asserting
  // where each lands is the only thing standing between the layout and a
  // future refactor quietly dropping a comment thread on top of the art.
  it("lays the overlay over the artwork, not under the post", () => {
    const { container } = render(<FeedRow post={post()} overlay={<span>controls</span>} />);
    const cover = container.querySelector("img")?.closest(".relative");
    expect(cover?.contains(screen.getByText("controls"))).toBe(true);
  });

  it("puts the foot slot below the caption, outside the artwork", () => {
    const { container } = render(
      <FeedRow post={post({ caption: "Devastating." })} actions={<span>thread</span>} />
    );
    const cover = container.querySelector("img")?.closest(".relative");
    const thread = screen.getByText("thread");
    expect(cover?.contains(thread)).toBe(false);
    // After the caption, so an open thread reads as the end of the post.
    expect(
      screen.getByText("Devastating.").compareDocumentPosition(thread) &
        Node.DOCUMENT_POSITION_FOLLOWING
    ).toBeTruthy();
  });

  it("falls back to the title when the media has no cover", () => {
    const noCover = post();
    noCover.media.coverUrl = null;
    const { container } = render(<FeedRow post={noCover} />);
    expect(container.querySelector("img")).toBeNull();
    expect(screen.getAllByText("Past Lives").length).toBeGreaterThan(0);
  });
});
