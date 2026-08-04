import { describe, expect, it } from "vitest";
import { shortRelativeTime } from "@/lib/relativeTime";

const now = new Date("2026-08-04T12:00:00.000Z");

const SECOND = 1000;
const MINUTE = 60 * SECOND;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const WEEK = 7 * DAY;

function ago(ms: number): Date {
  return new Date(now.getTime() - ms);
}

describe("shortRelativeTime", () => {
  it("shows 'now' for anything under a minute", () => {
    expect(shortRelativeTime(ago(0), now)).toBe("now");
    expect(shortRelativeTime(ago(59 * SECOND), now)).toBe("now");
  });

  it("shows whole minutes under an hour", () => {
    expect(shortRelativeTime(ago(MINUTE), now)).toBe("1m");
    expect(shortRelativeTime(ago(59 * MINUTE), now)).toBe("59m");
  });

  it("shows whole hours under a day", () => {
    expect(shortRelativeTime(ago(HOUR), now)).toBe("1h");
    expect(shortRelativeTime(ago(23 * HOUR), now)).toBe("23h");
  });

  it("shows whole days under a week", () => {
    expect(shortRelativeTime(ago(DAY), now)).toBe("1d");
    expect(shortRelativeTime(ago(6 * DAY), now)).toBe("6d");
  });

  it("falls back to weeks beyond a week", () => {
    expect(shortRelativeTime(ago(WEEK), now)).toBe("1w");
    expect(shortRelativeTime(ago(9 * WEEK), now)).toBe("9w");
  });

  it("clamps a future date to 'now' rather than showing a negative", () => {
    // Clock skew between Postgres and the browser can put a just-created
    // post slightly in the future; "-1m" would look broken.
    expect(shortRelativeTime(new Date(now.getTime() + HOUR), now)).toBe("now");
  });
});
