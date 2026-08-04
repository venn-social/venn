import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Mirrors `ios/Venn/Models/UserProfile.swift` — same shape, same table
 * (`public.profiles`). Per CLAUDE.md rule 17, keep these two in sync.
 */
export interface UserProfile {
  id: string;
  username: string;
  displayName: string | null;
  avatarUrl: string | null;
  bio: string | null;
  isPrivate: boolean;
  createdAt: string;
}

export interface FollowCounts {
  followers: number;
  following: number;
}

export interface ProfileRow {
  id: string;
  username: string;
  display_name: string | null;
  avatar_url: string | null;
  bio: string | null;
  is_private: boolean;
  created_at: string;
}

export function toUserProfile(row: ProfileRow): UserProfile {
  return {
    id: row.id,
    username: row.username,
    displayName: row.display_name,
    avatarUrl: row.avatar_url,
    bio: row.bio,
    isPrivate: row.is_private,
    createdAt: row.created_at,
  };
}

/** Mirrors `ProfileService.profile(for:)`. */
export async function fetchProfile(
  client: SupabaseClient,
  userId: string
): Promise<UserProfile | null> {
  const { data, error } = await client
    .from("profiles")
    .select()
    .eq("id", userId)
    .single();

  if (error) {
    if (error.code === "PGRST116") return null; // no matching row
    throw error;
  }
  return toUserProfile(data as ProfileRow);
}

/** Looks up a profile by username — how public-profile URLs are addressed (/[username], not a UUID). */
export async function fetchProfileByUsername(
  client: SupabaseClient,
  username: string
): Promise<UserProfile | null> {
  const { data, error } = await client.from("profiles").select().eq("username", username).single();

  if (error) {
    if (error.code === "PGRST116") return null; // no matching row
    throw error;
  }
  return toUserProfile(data as ProfileRow);
}

/**
 * Update the editable fields on the caller's own profile row. Mirrors
 * `ProfileService.updateProfile(userID:displayName:bio:)` — both columns
 * are nullable, so pass null to clear. RLS (`profiles_update_own`)
 * guarantees a user can only update their own row.
 */
export async function updateProfile(
  client: SupabaseClient,
  userId: string,
  displayName: string | null,
  bio: string | null
): Promise<void> {
  const { error } = await client
    .from("profiles")
    .update({ display_name: displayName, bio })
    .eq("id", userId);
  if (error) throw error;
}

/**
 * Flip the account between public and private. Mirrors
 * `ProfileService.updatePrivacy(userID:isPrivate:)` — a direct update,
 * since RLS already restricts it to the caller's own row.
 */
export async function updatePrivacy(
  client: SupabaseClient,
  userId: string,
  isPrivate: boolean
): Promise<void> {
  const { error } = await client
    .from("profiles")
    .update({ is_private: isPrivate })
    .eq("id", userId);
  if (error) throw error;
}

/** Mirrors `ProfileService.followCounts(for:)` — same `follow_counts` RPC. */
export async function fetchFollowCounts(
  client: SupabaseClient,
  userId: string
): Promise<FollowCounts> {
  const { data, error } = await client.rpc("follow_counts", { target: userId });
  if (error) throw error;
  const row = (data as FollowCounts[])[0];
  return row ?? { followers: 0, following: 0 };
}
