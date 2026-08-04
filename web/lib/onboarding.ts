import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Usernames that would shadow a static route under web/app/ (see
 * supabase/migrations/20260804120000_reserve_route_usernames.sql) — checked
 * client-side too so the live availability indicator doesn't show
 * "available" for a name that the DB constraint would reject at submit.
 * Includes routes not built yet: reserving a name is cheap, reclaiming one
 * after a user has taken it is not. This list and the CHECK constraint must
 * be changed together.
 */
const RESERVED_USERNAMES = new Set([
  "auth",
  "login",
  "profile",
  "requests",
  "feed",
  "explorer",
  "search",
  "settings",
  "composer",
  "notifications",
  "about",
  "terms",
  "privacy",
]);

/** Thrown by createProfile when the username is taken or reserved. */
export class UsernameTakenError extends Error {
  constructor(username: string) {
    super(`Username "${username}" is not available`);
    this.name = "UsernameTakenError";
  }
}

/** Mirrors OnboardingGate's hasProfile check. */
export async function hasProfile(client: SupabaseClient, userId: string): Promise<boolean> {
  const { data, error } = await client
    .from("profiles")
    .select("id")
    .eq("id", userId)
    .maybeSingle();
  if (error) throw error;
  return data !== null;
}

/**
 * Advisory only — same as OnboardingService.isUsernameAvailable. The DB's
 * unique and reserved-word constraints are the real authority at insert
 * time; this just powers the live ✓/✗ indicator.
 */
export async function isUsernameAvailable(
  client: SupabaseClient,
  username: string
): Promise<boolean> {
  if (RESERVED_USERNAMES.has(username)) return false;
  const { data, error } = await client
    .from("profiles")
    .select("id")
    .eq("username", username)
    .maybeSingle();
  if (error) throw error;
  return data === null;
}

/**
 * Mirrors OnboardingService.createProfile. A unique-violation (23505,
 * plain "taken") or check-violation (23514 — the reserved-word
 * constraint; format is validated client-side first so this realistically
 * only fires for reserved words) both map to UsernameTakenError — not
 * worth distinguishing which constraint fired.
 */
export async function createProfile(
  client: SupabaseClient,
  userId: string,
  username: string,
  displayName: string | null
): Promise<void> {
  const { error } = await client
    .from("profiles")
    .insert({ id: userId, username, display_name: displayName });
  if (error) {
    if (error.code === "23505" || error.code === "23514") {
      throw new UsernameTakenError(username);
    }
    throw error;
  }
}

/**
 * Mirrors ProfileService.uploadAvatar — same bucket ("avatars"), same
 * folder-scoped path convention, same cache-busting query param (the
 * path is stable across re-uploads, so a browser would otherwise keep
 * serving a stale cached image).
 */
export async function uploadAvatar(
  client: SupabaseClient,
  userId: string,
  blob: Blob
): Promise<string> {
  const path = `${userId.toLowerCase()}/avatar.jpg`;
  const { error: uploadError } = await client.storage.from("avatars").upload(path, blob, {
    cacheControl: "3600",
    contentType: "image/jpeg",
    upsert: true
  });
  if (uploadError) throw uploadError;

  const { data } = client.storage.from("avatars").getPublicUrl(path);
  const url = `${data.publicUrl}?v=${Date.now()}`;

  const { error: updateError } = await client
    .from("profiles")
    .update({ avatar_url: url })
    .eq("id", userId);
  if (updateError) throw updateError;

  return url;
}