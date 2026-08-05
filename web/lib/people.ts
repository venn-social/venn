import type { SupabaseClient } from "@supabase/supabase-js";
import { toUserProfile, type ProfileRow, type UserProfile } from "@/lib/profile";

/**
 * Build a PostgREST contains-pattern (`*term*`) from raw input.
 *
 * SECURITY: the result is interpolated into a raw `or(...)` filter string
 * that PostgREST parses itself. In that string commas separate conditions,
 * dots separate column/operator/value, parens group, and quotes delimit —
 * all syntax. `*` and `%` are multi-character wildcards. Untrusted
 * characters would corrupt the filter or widen the match arbitrarily, so
 * only letters, digits, spaces, `_`, and `-` survive.
 *
 * `_` is kept despite being a single-character LIKE wildcard: it's part of
 * the username alphabet and still matches itself, so the worst case is a
 * benign over-match.
 *
 * Returns "" when nothing searchable remains — callers must treat that as
 * "no results" and issue no query. Ports PeopleSearchService.containsPattern.
 */
export function containsPattern(query: string): string {
  const kept = [...query].filter((character) => /[\p{L}\p{Nd} _-]/u.test(character)).join("");
  const term = kept.replace(/\s+/g, " ").trim();
  return term.length === 0 ? "" : `*${term}*`;
}

/** Mirrors PeopleSearchService.searchProfiles. */
export async function searchProfiles(
  client: SupabaseClient,
  query: string,
  limit = 20
): Promise<UserProfile[]> {
  const pattern = containsPattern(query);
  if (pattern === "") return [];

  const { data, error } = await client
    .from("profiles")
    .select()
    .or(`username.ilike.${pattern},display_name.ilike.${pattern}`)
    .order("username", { ascending: true })
    .limit(limit);

  if (error) throw error;
  return ((data ?? []) as ProfileRow[]).map(toUserProfile);
}
