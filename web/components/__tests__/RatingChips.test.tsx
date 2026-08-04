import { fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { RatingChips } from "@/components/RatingChips";

describe("RatingChips", () => {
  it("offers the same three choices as iOS", () => {
    render(<RatingChips value={null} onChange={() => {}} />);
    expect(screen.getByRole("button", { name: /Love/ })).toBeDefined();
    expect(screen.getByRole("button", { name: /Like/ })).toBeDefined();
    expect(screen.getByRole("button", { name: /Dislike/ })).toBeDefined();
  });

  it("reports the chosen sentiment", () => {
    const onChange = vi.fn();
    render(<RatingChips value={null} onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", { name: /Love/ }));
    expect(onChange).toHaveBeenCalledWith("love");
  });

  it("clears the choice when the selected chip is clicked again", () => {
    // Tapping your current rating should un-set it, so "skip" stays reachable
    // without a separate control.
    const onChange = vi.fn();
    render(<RatingChips value="like" onChange={onChange} />);
    fireEvent.click(screen.getByRole("button", { name: /Like/ }));
    expect(onChange).toHaveBeenCalledWith(null);
  });

  it("marks the selected chip as pressed for assistive tech", () => {
    render(<RatingChips value="dislike" onChange={() => {}} />);
    expect(screen.getByRole("button", { name: /Dislike/ }).getAttribute("aria-pressed")).toBe(
      "true"
    );
    expect(screen.getByRole("button", { name: /Love/ }).getAttribute("aria-pressed")).toBe("false");
  });
});
