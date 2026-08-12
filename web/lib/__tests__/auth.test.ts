import { describe, expect, it } from "vitest";
import { RESEND_COOLDOWN_SECONDS, canResend, resendSecondsRemaining } from "@/lib/auth";

/**
 * Mirrors the resend-cooldown cases in iOS's AuthViewModelTests. A cooldown
 * that differs between platforms is one someone routes around by switching
 * device, so the two have to agree case for case.
 */
const SENT_AT = 1_700_000_000_000;
const after = (seconds: number) => SENT_AT + seconds * 1000;

describe("resendSecondsRemaining", () => {
  it("is the full cooldown the instant the email goes out", () => {
    expect(resendSecondsRemaining(SENT_AT, SENT_AT)).toBe(RESEND_COOLDOWN_SECONDS);
  });

  it("counts down as time passes", () => {
    expect(resendSecondsRemaining(SENT_AT, after(10))).toBe(20);
    expect(resendSecondsRemaining(SENT_AT, after(29))).toBe(1);
  });

  it("rounds up, so the button never claims less time than remains", () => {
    // At 29.5s elapsed there is half a second left. Showing "0s" while the
    // control is still disabled reads as broken.
    expect(resendSecondsRemaining(SENT_AT, SENT_AT + 29_500)).toBe(1);
  });

  it("reaches zero exactly on the cooldown", () => {
    expect(resendSecondsRemaining(SENT_AT, after(RESEND_COOLDOWN_SECONDS))).toBe(0);
  });

  it("never goes negative once the cooldown has long passed", () => {
    expect(resendSecondsRemaining(SENT_AT, after(600))).toBe(0);
  });

  it("is zero before anything has been sent", () => {
    expect(resendSecondsRemaining(null, SENT_AT)).toBe(0);
  });

  it("survives a clock that jumps backwards", () => {
    // System clock changes and DST have both produced negative elapsed time
    // in the wild; the cooldown should cap, not go haywire.
    expect(resendSecondsRemaining(SENT_AT, SENT_AT - 60_000)).toBe(90);
  });
});

describe("canResend", () => {
  it("is false while the cooldown runs", () => {
    expect(canResend(SENT_AT, after(5))).toBe(false);
  });

  it("is true once the cooldown elapses", () => {
    expect(canResend(SENT_AT, after(RESEND_COOLDOWN_SECONDS))).toBe(true);
  });

  it("is false before anything has been sent", () => {
    // Zero seconds remaining is not the same as "ready" — there is nothing
    // to resend yet, and the two must not be conflated.
    expect(canResend(null, SENT_AT)).toBe(false);
  });
});
