import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { MediaCover } from "@/components/MediaCover";
import type { Media } from "@/lib/media";

function media(overrides: Partial<Media> = {}): Media {
  return {
    id: "m1",
    kind: "book",
    title: "Piranesi",
    year: 2020,
    primaryCreator: "Susanna Clarke",
    coverUrl: "https://example.test/piranesi.jpg",
    ...overrides
  };
}

describe("MediaCover", () => {
  it("renders the artwork when there is one", () => {
    render(<MediaCover media={media()} />);
    const image = screen.getByRole("img", { name: "Piranesi" });
    expect(image.getAttribute("src")).toBe("https://example.test/piranesi.jpg");
  });

  it("titles the image so the shelf is navigable without sight", () => {
    // Unlike Avatar, the title is not repeated next to the cover in a
    // shelf grid — so here the alt text is the only label.
    render(<MediaCover media={media()} />);
    expect(screen.getByRole("img").getAttribute("alt")).toBe("Piranesi");
  });

  it("falls back to the title when there is no cover", () => {
    const { container } = render(<MediaCover media={media({ coverUrl: null })} />);
    expect(container.querySelector("img")).toBeNull();
    expect(screen.getByText("Piranesi")).toBeDefined();
  });
});
