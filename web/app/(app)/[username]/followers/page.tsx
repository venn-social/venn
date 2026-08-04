import { notFound, redirect } from "next/navigation";
import { ProfileRow } from "@/components/ProfileRow";
import { fetchFollowers, fetchFollowStatus } from "@/lib/follow";
import { fetchProfileByUsername } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";

interface FollowersPageProps {
  params: Promise<{ username: string }>;
}

/**
 * Followers of one profile. Ports FollowListView.swift's `.followers` kind,
 * including its title and empty-state copy.
 */
export default async function FollowersPage({ params }: FollowersPageProps) {
  const { username } = await params;
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const profile = await fetchProfileByUsername(supabase, username);
  if (!profile) {
    notFound();
  }

  // A private account's edges are hidden from non-followers by RLS, so
  // render the same locked message rather than a misleading empty list.
  const followStatus =
    profile.id === user.id ? "accepted" : await fetchFollowStatus(supabase, user.id, profile.id);
  const isLocked = profile.isPrivate && followStatus !== "accepted";

  const followers = isLocked ? [] : await fetchFollowers(supabase, profile.id);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-2 px-4 py-8">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Followers</h1>

      {isLocked ? (
        <p className="text-(--color-text-secondary)">
          This account is private. Follow @{profile.username} to see who follows them.
        </p>
      ) : followers.length === 0 ? (
        <div className="flex flex-col gap-1 py-8 text-center">
          <p className="font-semibold text-(--color-text-primary)">No followers yet</p>
          <p className="text-(--color-text-secondary)">Followers will show up here.</p>
        </div>
      ) : (
        <ul className="flex flex-col divide-y divide-(--color-separator)">
          {followers.map((follower) => (
            <li key={follower.id}>
              <ProfileRow profile={follower} />
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
