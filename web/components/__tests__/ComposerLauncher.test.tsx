import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { ComposerLauncher } from "@/components/ComposerLauncher";
import { candidateFromMedia } from "@/lib/catalog/types";

vi.mock("next/navigation", () => ({
  useRouter: () => ({ push: vi.fn(), refresh: vi.fn() })
}));

const media = {
  kind: "movie" as const,
  title: "Past Lives",
  year: 2023,
  primaryCreator: "Celine Song",
  coverUrl: null,
  externalSource: "tmdb" as const,
  externalId: "666277"
};

describe("ComposerLauncher", () => {
  it("stays out of the way until asked", () => {
    render(
      <ComposerLauncher userId="u1">
        Log this
      </ComposerLauncher>
    );
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("opens over the page instead of navigating away from it", () => {
    // The whole point: logging is a detour, and you should get back the
    // page you were reading rather than having to navigate to it.
    render(<ComposerLauncher userId="u1">Log this</ComposerLauncher>);

    fireEvent.click(screen.getByRole("button", { name: "Log this" }));
    expect(screen.getByRole("dialog", { name: "Log something" })).toBeDefined();
  });

  it("arrives with the title already chosen, not a search for it", () => {
    // Opened from a title's own page, the thing to log is already decided;
    // asking the user to find it again is a question they just answered.
    render(
      <ComposerLauncher userId="u1" initialPicked={candidateFromMedia(media)}>
        Log this
      </ComposerLauncher>
    );

    fireEvent.click(screen.getByRole("button", { name: "Log this" }));
    expect(screen.getByRole("heading", { name: "Past Lives" })).toBeDefined();
    expect(screen.queryByPlaceholderText(/Search/)).toBeNull();
  });

  it("closes on Escape and on the backdrop, but not from inside", () => {
    render(<ComposerLauncher userId="u1">Log this</ComposerLauncher>);
    const open = () => fireEvent.click(screen.getByRole("button", { name: "Log this" }));

    open();
    fireEvent.keyDown(window, { key: "Escape" });
    expect(screen.queryByRole("dialog")).toBeNull();

    open();
    // A click inside the sheet must not dismiss it, or picking a title
    // would close the thing you picked it in.
    fireEvent.click(screen.getByRole("heading", { name: "Log something" }));
    expect(screen.getByRole("dialog")).toBeDefined();

    fireEvent.click(screen.getByRole("dialog"));
    expect(screen.queryByRole("dialog")).toBeNull();
  });

  it("names the trigger when it is only an icon", () => {
    render(
      <ComposerLauncher userId="u1" label="Log">
        <svg />
      </ComposerLauncher>
    );
    expect(screen.getByRole("button", { name: "Log" })).toBeDefined();
  });
});

describe("candidateFromMedia", () => {
  it("rebuilds the catalog identity of a row we already hold", () => {
    expect(candidateFromMedia(media)).toEqual({
      id: "tmdb:movie:666277",
      title: "Past Lives",
      primaryCreator: "Celine Song",
      year: 2023,
      coverUrl: null,
      overview: null,
      externalId: "666277",
      externalSource: "tmdb",
      kind: "movie"
    });
  });

  it("gives nothing for a hand-typed row, which has no catalog identity", () => {
    expect(candidateFromMedia({ ...media, externalSource: null, externalId: null })).toBeNull();
  });
});
