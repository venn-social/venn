import { describe, expect, it } from "vitest";
import { hasCompletionCookie, isExemptPath } from "@/lib/onboardingGate";

describe("isExemptPath", () => {
  it("exempts onboarding itself — it's the redirect destination", () => {
    expect(isExemptPath("/onboarding")).toBe(true);
  });

  it("exempts the auth paths, where there's no profile to check yet", () => {
    expect(isExemptPath("/login")).toBe(true);
    expect(isExemptPath("/auth/callback")).toBe(true);
  });

  it("gates the ordinary app routes", () => {
    expect(isExemptPath("/feed")).toBe(false);
    expect(isExemptPath("/explorer")).toBe(false);
    expect(isExemptPath("/profile")).toBe(false);
    expect(isExemptPath("/someusername")).toBe(false);
  });
});

describe("hasCompletionCookie", () => {
  it("skips the lookup when the cookie vouches for this user", () => {
    expect(hasCompletionCookie("user-1", "user-1")).toBe(true);
  });

  it("does not trust a cookie left behind by a different account", () => {
    // Sign out, sign in as someone else on the same browser: without the
    // id check this would carry the previous person's answer over.
    expect(hasCompletionCookie("user-1", "user-2")).toBe(false);
  });

  it("falls back to the lookup when there is no cookie", () => {
    expect(hasCompletionCookie(undefined, "user-1")).toBe(false);
    expect(hasCompletionCookie("", "user-1")).toBe(false);
  });
});
