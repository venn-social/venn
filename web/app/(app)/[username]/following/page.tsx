import { notFound, redirect } from "next/navigation";
import { ProfileRow } from "@/components/ProfileRow";
import { fetchFollowing, fetchFollowStatus } from "@/lib/follow";
import { fetchProfileByUsername } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";

interface FollowingPageProps {
  params: Promise<{ username: string }>;
}

/**
 * Who one profile follows. Ports FollowListView.swift's `.following` kind.
 * Its empty-state message drops iOS's "Find people in the Explorer tab"
 * pointer, since web has no Explorer yet (docs/TECH_DEBT.md row 16).
 */
export default async function FollowingPage({ params }: FollowingPageProps) {
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

  const followStatus =
    profile.id === user.id ? "accepted" : await fetchFollowStatus(supabase, user.id, profile.id);
  const isLocked = profile.isPrivate && followStatus !== "accepted";

  const following = isLocked ? [] : await fetchFollowing(supabase, profile.id);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-2 px-4 py-8">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Following</h1>

      {isLocked ? (
        <p className="text-(--color-text-secondary)">
          This account is private. Follow @{profile.username} to see who they follow.
        </p>
      ) : following.length === 0 ? (
        <div className="flex flex-col gap-1 py-8 text-center">
          <p className="font-semibold text-(--color-text-primary)">Not following anyone yet</p>
        </div>
      ) : (
        <ul className="flex flex-col divide-y divide-(--color-separator)">
          {following.map((followee) => (
            <li key={followee.id}>
              <ProfileRow profile={followee} />
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
