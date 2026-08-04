import { redirect } from "next/navigation";
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

  const counts = await fetchFollowCounts(supabase, user.id);
  const initial = (profile.displayName ?? profile.username).charAt(0).toUpperCase();

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
      <div className="flex items-start gap-3">
        <div className="flex h-[72px] w-[72px] shrink-0 items-center justify-center rounded-full bg-(--color-graphite) text-xl font-semibold text-(--color-on-accent)">
          {initial}
        </div>
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
    </main>
  );
}
