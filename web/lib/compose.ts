import type { SupabaseClient } from "@supabase/supabase-js";
import type { MediaCandidate } from "@/lib/catalog/types";
import type { PostAction } from "@/lib/feed";

/** The three-way sentiment from the rating step. Null means "skip". */
export type RatingChoice = "love" | "like" | "dislike";

/** Exactly the mapping ComposerViewModel.submit uses. */
export function ratingToPost(choice: RatingChoice | null): {
  action: PostAction;
  rating: number | null;
} {
  switch (choice) {
    case "love":
      return { action: "rated", rating: 5 };
    case "like":
      return { action: "rated", rating: 3 };
    case "dislike":
      return { action: "rated", rating: 1 };
    default:
      return { action: "logged", rating: null };
  }
}

/** True for the P0429 raised by the posts_rate_limit trigger. */
export function isRateLimited(error: unknown): boolean {
  return (error as { code?: string } | null)?.code === "P0429";
}

/**
 * Returns the id of the existing or newly-inserted media row.
 *
 * Select-then-insert rather than upsert: PostgREST cannot target the partial
 * unique index media_external_unique directly. A concurrent insert of the
 * same (source, id) pair is caught by the constraint, and we re-read rather
 * than fail — the row existing is the outcome we wanted. Ports
 * ComposerService.upsertMedia.
 */
export async function upsertMedia(
  client: SupabaseClient,
  candidate: MediaCandidate
): Promise<string> {
  const existing = await client
    .from("media")
    .select("id")
    .eq("external_source", candidate.externalSource)
    .eq("external_id", candidate.externalId)
    .limit(1);
  if (existing.error) throw existing.error;
  if (existing.data?.[0]) return existing.data[0].id as string;

  const inserted = await client
    .from("media")
    .insert({
      kind: candidate.kind,
      title: candidate.title,
      year: candidate.year,
      primary_creator: candidate.primaryCreator,
      cover_url: candidate.coverUrl,
      external_id: candidate.externalId,
      external_source: candidate.externalSource
    })
    .select("id");

  if (inserted.error) {
    // 23505: someone inserted the same candidate between our select and
    // insert. Re-read theirs instead of surfacing a conflict.
    if (inserted.error.code === "23505") {
      const retry = await client
        .from("media")
        .select("id")
        .eq("external_source", candidate.externalSource)
        .eq("external_id", candidate.externalId)
        .limit(1);
      if (retry.error) throw retry.error;
      if (retry.data?.[0]) return retry.data[0].id as string;
    }
    throw inserted.error;
  }

  const id = inserted.data?.[0]?.id as string | undefined;
  if (!id) throw new Error("Media insert returned no id");
  return id;
}

export async function createPost(
  client: SupabaseClient,
  options: {
    authorId: string;
    mediaId: string;
    action: PostAction;
    rating: number | null;
    caption: string | null;
  }
): Promise<void> {
  const { error } = await client.from("posts").insert({
    author_id: options.authorId,
    media_id: options.mediaId,
    action: options.action,
    rating: options.rating,
    caption: options.caption
  });
  if (error) throw error;
}
