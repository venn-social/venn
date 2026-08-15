import { act, fireEvent, render, screen } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { DetailUnavailable } from "@/components/DetailUnavailable";

const refresh = vi.fn();
vi.mock("next/navigation", () => ({ useRouter: () => ({ refresh }) }));

describe("DetailUnavailable", () => {
  it("says the rest of the page is still correct", () => {
    // The failure is partial. Implying the whole page is wrong would be a
    // worse lie than the silence it replaces.
    render(<DetailUnavailable />);
    expect(screen.getByRole("status").textContent).toMatch(/still correct/i);
  });

  it("retries by re-running the server render, not by fetching from an API", () => {
    // A client island calling our own API would mean re-introducing the
    // catalog detail route deleted in #177. router.refresh() gets the same
    // recovery with no new surface.
    render(<DetailUnavailable />);
    fireEvent.click(screen.getByRole("button", { name: "Try again" }));
    expect(refresh).toHaveBeenCalledTimes(1);
  });

  it("does not leave the button stuck after a retry that also fails", () => {
    vi.useFakeTimers();
    render(<DetailUnavailable />);
    const button = screen.getByRole("button", { name: "Try again" });

    fireEvent.click(button);
    expect((screen.getByRole("button", { name: "Trying…" }) as HTMLButtonElement).disabled).toBe(true);

    // The timer flips state, so React needs to flush inside act().
    act(() => {
      vi.advanceTimersByTime(2000);
    });
    expect((screen.getByRole("button", { name: "Try again" }) as HTMLButtonElement).disabled).toBe(false);
    vi.useRealTimers();
  });
});
