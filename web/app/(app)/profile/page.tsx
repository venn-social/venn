import { redirect } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { ProfileShelves } from "@/components/ProfileShelves";
import { fetchCollection, fetchWatchlist } from "@/lib/library";
import { createClient } from "@/lib/supabase/server";
import { fetchFollowCounts, fetchProfile } from "@/lib/profile";

/**
 * Read-only "my profile" page — Phase 1 scope (see
 * docs/superpowers/specs/2026-07-30-web-app-phase1-foundation-design.md).
 * Mirrors ProfileHeaderView.swift's layout: avatar, name, handle,
 * de-emphasized follower/following counts.
 */
export default async function ProfilePage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const profile = await fetchProfile(supabase, user.id);
  if (!profile) {
    // Auth user exists but the profiles-row trigger hasn't run yet —
    // mirrors ProfileViewModel's "row missing" error state on iOS.
    return (
      <main className="flex min-h-screen items-center justify-center px-4 text-center">
        <p className="text-(--color-text-secondary)">Couldn&apos;t load your profile.</p>
      </main>
    );
  }

  // Shelves are non-critical: a failed library query should thin the page
  // out, not replace the whole profile with an error.
  const [counts, collectionResult, watchlistResult] = await Promise.all([
    fetchFollowCounts(supabase, user.id),
    fetchCollection(supabase, user.id).catch(() => []),
    fetchWatchlist(supabase, user.id).catch(() => []),
  ]);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
      <div className="flex items-start gap-3">
        <Avatar name={profile.displayName ?? profile.username} avatarUrl={profile.avatarUrl} />
        <div className="flex flex-col gap-0.5">
          <h1 className="text-xl font-semibold text-(--color-text-primary)">
            {profile.displayName ?? profile.username}
          </h1>
          <p className="text-(--color-text-secondary)">@{profile.username}</p>
          <div className="mt-1 flex gap-4 text-sm text-(--color-text-secondary)">
            <span>
              <strong className="font-medium">{counts.followers}</strong> Followers
            </span>
            <span>
              <strong className="font-medium">{counts.following}</strong> Following
            </span>
          </div>
        </div>
      </div>

      {profile.bio && <p className="text-(--color-text-primary)">{profile.bio}</p>}

      <ProfileShelves
        collection={collectionResult}
        watchlist={watchlistResult}
        emptyCollection="Nothing in your collection yet."
        emptyWatchlist="Your watchlist is empty."
      />
    </main>
  );
}
