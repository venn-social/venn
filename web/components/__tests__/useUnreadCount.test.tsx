import { renderHook, waitFor } from "@testing-library/react";
import { describe, expect, it, vi } from "vitest";
import { useUnreadCount } from "@/components/useUnreadCount";

const handlers: Array<() => void> = [];
const removeChannel = vi.fn();
const fetchUnreadCount = vi.fn();

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({
    channel: () => ({
      on: (_event: string, _filter: unknown, handler: () => void) => {
        handlers.push(handler);
        return { subscribe: () => "channel" };
      }
    }),
    removeChannel
  })
}));

vi.mock("@/lib/notifications", () => ({
  fetchUnreadCount: (...args: unknown[]) => fetchUnreadCount(...args)
}));

describe("useUnreadCount", () => {
  it("starts on the server's count", () => {
    const { result } = renderHook(() => useUnreadCount(3));
    expect(result.current).toBe(3);
  });

  it("re-reads the count when something changes, rather than incrementing", () => {
    // Incrementing locally cannot handle a notification marked read in
    // another tab; re-reading handles both directions.
    fetchUnreadCount.mockResolvedValue(7);
    const { result } = renderHook(() => useUnreadCount(3));

    handlers.at(-1)?.();

    return waitFor(() => expect(result.current).toBe(7));
  });

  it("keeps the last known count when the re-read fails", async () => {
    // Blanking a badge that was correct a second ago is worse than being
    // briefly stale.
    fetchUnreadCount.mockRejectedValue(new Error("offline"));
    const { result } = renderHook(() => useUnreadCount(4));

    handlers.at(-1)?.();

    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(result.current).toBe(4);
  });

  it("follows the server again on navigation", () => {
    // Otherwise the badge keeps whatever the first render happened to see.
    const { result, rerender } = renderHook(({ n }) => useUnreadCount(n), {
      initialProps: { n: 1 }
    });
    rerender({ n: 5 });
    expect(result.current).toBe(5);
  });

  it("unsubscribes on unmount", () => {
    // A channel per navigation that never closes is a leak that only shows
    // up after a long session.
    const { unmount } = renderHook(() => useUnreadCount(0));
    unmount();
    expect(removeChannel).toHaveBeenCalled();
  });
});
