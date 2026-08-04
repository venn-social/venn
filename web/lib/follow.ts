import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

/**
 * Mirrors ios/Venn/Features/Profile/FollowService.swift's FollowStatus —
 * the result of asking to follow someone, per request_follow: instant for
 * a public account, pending approval for a private one.
 */
export type FollowStatus = "pending" | "accepted";

interface FollowStatusRow {
  status: string;
}

/** Mirrors FollowService.followStatus(followerID:followeeID:). */
export async function fetchFollowStatus(
  client: SupabaseClient,
  followerId: string,
  followeeId: string
): Promise<FollowStatus | null> {
  const { data, error } = await client
    .from("follows")
    .select("status")
    .eq("follower_id", followerId)
    .eq("followee_id", followeeId)
    .limit(1);

  if (error) throw error;
  const raw = (data as FollowStatusRow[])[0]?.status;
  return raw === "pending" || raw === "accepted" ? raw : null;
}

/**
 * Mirrors FollowService.requestFollow(followerID:followeeID:) — same
 * request_follow RPC. Returns the resulting status: "accepted" for a
 * public target (the edge exists immediately) or "pending" for a private
 * one (the followee must approve via respondToRequest).
 */
export async function requestFollow(
  client: SupabaseClient,
  targetId: string
): Promise<FollowStatus> {
  const { data, error } = await client.rpc("request_follow", { target: targetId });
  if (error) throw error;
  if (data !== "pending" && data !== "accepted") {
    throw new Error(`request_follow returned unexpected status: ${String(data)}`);
  }
  return data;
}

/**
 * Mirrors FollowService.unfollow(followerID:followeeID:). Deletes the
 * edge — unfollowing an accepted edge, or withdrawing/declining a
 * pending one. Idempotent: deleting a non-existent edge succeeds.
 */
export async function unfollow(
  client: SupabaseClient,
  followerId: string,
  followeeId: string
): Promise<void> {
  const { error } = await client
    .from("follows")
    .delete()
    .eq("follower_id", followerId)
    .eq("followee_id", followeeId);
  if (error) throw error;
}

/**
 * Mirrors FollowService.respondToRequest(followerID:followeeID:accept:) —
 * same respond_to_follow_request RPC. Only the followee (inferred
 * server-side from auth.uid()) may call this for their own incoming
 * requests.
 */
export async function respondToRequest(
  client: SupabaseClient,
  requesterId: string,
  accept: boolean
): Promise<void> {
  const { error } = await client.rpc("respond_to_follow_request", {
    requester: requesterId,
    accept
  });
  if (error) throw error;
}

/** One `follows` row with the follower profile embedded (internal for tests). */
export interface FollowerRow {
  follower: ProfileRow;
}

/** Pure row mapping — mirrors FollowerRow.follower in FollowService.swift. */
export function mapFollowerRows(rows: FollowerRow[]): UserProfile[] {
  return rows.map((row) => toUserProfile(row.follower));
}

/** One `follows` row with the followee profile embedded (internal for tests). */
export interface FollowingRow {
  followee: ProfileRow;
}

/** Pure row mapping — mirrors FollowingRow.followee in FollowService.swift. */
export function mapFollowingRows(rows: FollowingRow[]): UserProfile[] {
  return rows.map((row) => toUserProfile(row.followee));
}

/**
 * Accepted followers of `userId`, newest first. Mirrors
 * FollowService.followers(of:limit:). Only accepted edges — a pending
 * request is not a follower yet.
 */
export async function fetchFollowers(
  client: SupabaseClient,
  userId: string,
  limit = 50
): Promise<UserProfile[]> {
  const { data, error } = await client
    .from("follows")
    .select("created_at, follower:profiles!follows_follower_id_fkey(*)")
    .eq("followee_id", userId)
    .eq("status", "accepted")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return mapFollowerRows(data as unknown as FollowerRow[]);
}

/** Accounts `userId` follows, newest first. Mirrors FollowService.following(of:limit:). */
export async function fetchFollowing(
  client: SupabaseClient,
  userId: string,
  limit = 50
): Promise<UserProfile[]> {
  const { data, error } = await client
    .from("follows")
    .select("created_at, followee:profiles!follows_followee_id_fkey(*)")
    .eq("follower_id", userId)
    .eq("status", "accepted")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return mapFollowingRows(data as unknown as FollowingRow[]);
}

/** Mirrors FollowService.pendingRequests(for:limit:). */
export async function fetchPendingRequests(
  client: SupabaseClient,
  userId: string,
  limit = 50
): Promise<UserProfile[]> {
  const { data, error } = await client
    .from("follows")
    .select("created_at, follower:profiles!follows_follower_id_fkey(*)")
    .eq("followee_id", userId)
    .eq("status", "pending")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return mapFollowerRows(data as unknown as FollowerRow[]);
}
