import { describe, expect, it } from "vitest";
import { HALL_CAPACITY, nextFreeSlot } from "@/lib/hallOfFame";

/**
 * Slot assignment. The cap itself is the database's job — a range check
 * plus a unique index, covered by supabase/tests/hall_of_fame_test.sql —
 * so what is worth testing here is which slot the next thing takes.
 */
describe("nextFreeSlot", () => {
  it("starts at one on an empty hall", () => {
    expect(nextFreeSlot([])).toBe(1);
  });

  it("fills the gap left by something removed, not the end", () => {
    // Otherwise taking an item out of the middle leaves a hole in the grid
    // that nothing can ever occupy.
    expect(nextFreeSlot([1, 2, 4, 5])).toBe(3);
  });

  it("takes the next slot along when the hall is contiguous", () => {
    expect(nextFreeSlot([1, 2, 3])).toBe(4);
  });

  it("says so when the hall is full", () => {
    const full = Array.from({ length: HALL_CAPACITY }, (_, i) => i + 1);
    expect(nextFreeSlot(full)).toBeNull();
  });

  it("is not confused by slots arriving out of order", () => {
    expect(nextFreeSlot([5, 1, 3, 2])).toBe(4);
  });

  it("caps at twelve, matching the constraint that enforces it", () => {
    expect(HALL_CAPACITY).toBe(12);
    expect(nextFreeSlot([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11])).toBe(12);
  });
});
