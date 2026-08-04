import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Avatar } from "@/components/Avatar";

describe("Avatar", () => {
  // The <img> carries alt="" because the person's name is always rendered
  // next to it — announcing it twice is noise for a screen reader. That
  // also keeps it out of the a11y tree, so these query the DOM directly
  // rather than by role.
  it("renders the image when a URL is present", () => {
    const { container } = render(<Avatar name="Ada" avatarUrl="https://example.test/a.jpg" />);
    expect(container.querySelector("img")?.getAttribute("src")).toBe("https://example.test/a.jpg");
  });

  it("falls back to the first initial when there is no URL", () => {
    const { container } = render(<Avatar name="Ada" avatarUrl={null} />);
    expect(screen.getByText("A")).toBeDefined();
    expect(container.querySelector("img")).toBeNull();
  });

  it("uppercases a lowercase name's initial", () => {
    render(<Avatar name="ada" avatarUrl={null} />);
    expect(screen.getByText("A")).toBeDefined();
  });

  it("renders a fallback glyph for an empty name rather than an empty circle", () => {
    render(<Avatar name="" avatarUrl={null} />);
    expect(screen.getByText("?")).toBeDefined();
  });
});
