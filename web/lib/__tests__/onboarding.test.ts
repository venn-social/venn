import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { createProfile, isUsernameAvailable, UsernameTakenError } from "@/lib/onboarding";

function makeClientStub(insertError: { code: string } | null = null) {
  const client = {
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          maybeSingle: vi.fn(async () => ({ data: null, error: null }))
        }))
      })),
      insert: vi.fn(async () => ({ error: insertError }))
    }))
  };
  return client as unknown as SupabaseClient;
}

describe("isUsernameAvailable", () => {
  it("returns false for a reserved username without querying", async () => {
    const client = makeClientStub();
    const available = await isUsernameAvailable(client, "profile");
    expect(available).toBe(false);
    expect(client.from).not.toHaveBeenCalled();
  });

  it("returns true when no row matches", async () => {
    const client = makeClientStub();
    const available = await isUsernameAvailable(client, "ada");
    expect(available).toBe(true);
  });

  it("reports every route-shadowing username as unavailable without a query", async () => {
    // These shadow real or planned static routes under web/app/. Kept in
    // lockstep with the profiles_username_not_reserved CHECK constraint.
    const client = makeClientStub();
    for (const reserved of ["feed", "explorer", "settings", "composer"]) {
      expect(await isUsernameAvailable(client, reserved)).toBe(false);
    }
    expect(client.from).not.toHaveBeenCalled();
  });
});

describe("createProfile", () => {
  it("throws UsernameTakenError on a unique-violation (23505)", async () => {
    const client = makeClientStub({ code: "23505" });
    await expect(createProfile(client, "user-1", "ada", null)).rejects.toThrow(UsernameTakenError);
  });

  it("throws UsernameTakenError on a check-violation (23514 — reserved word)", async () => {
    const client = makeClientStub({ code: "23514" });
    await expect(createProfile(client, "user-1", "profile", null)).rejects.toThrow(
      UsernameTakenError
    );
  });

  it("resolves when the insert succeeds", async () => {
    const client = makeClientStub();
    await expect(createProfile(client, "user-1", "ada", null)).resolves.toBeUndefined();
  });

  it("rethrows an unrelated error as-is", async () => {
    const client = makeClientStub({ code: "500" });
    await expect(createProfile(client, "user-1", "ada", null)).rejects.not.toThrow(
      UsernameTakenError
    );
  });
});