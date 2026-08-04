import { notFound, redirect } from "next/navigation";
import { Avatar } from "@/components/Avatar";
import { FollowButton } from "@/components/FollowButton";
import { LockedProfile } from "@/components/LockedProfile";
import { ProfileShelves } from "@/components/ProfileShelves";
import { VennOverlap } from "@/components/VennOverlap";
import { fetchFollowStatus } from "@/lib/follow";
import { fetchCollection, fetchWatchlist, type LibraryItem } from "@/lib/library";
import { fetchOverlap } from "@/lib/overlap";
import { fetchFollowCounts, fetchProfileByUsername } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";

interface PublicProfilePageProps {
  params: Promise<{ username: string }>;
}

export default async function PublicProfilePage({ params }: PublicProfilePageProps) {
  const { username } = await params;
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const profile = await fetchProfileByUsername(supabase, username);
  if (!profile) {
    notFound();
  }
  if (profile.id === user.id) {
    redirect("/profile");
  }

  const [countsResult, followStatusResult] = await Promise.allSettled([
    fetchFollowCounts(supabase, profile.id),
    fetchFollowStatus(supabase, user.id, profile.id)
  ]);

  const counts: Awaited<ReturnType<typeof fetchFollowCounts>> | null =
    countsResult.status === "fulfilled" ? countsResult.value : null;
  // Fail closed: a failed lookup must never be treated as "accepted", or a
  // private profile's gated content could leak because a query errored.
  const followStatus = followStatusResult.status === "fulfilled" ? followStatusResult.value : null;

  const isLocked = profile.isPrivate && followStatus !== "accepted";

  let overlap = null;
  let overlapFailed = false;
  let collection: LibraryItem[] = [];
  let watchlist: LibraryItem[] = [];
  // Gated server-side: a locked profile's shelves are never fetched, so
  // they never reach the browser at all. RLS is still the real boundary.
  if (!isLocked) {
    try {
      overlap = await fetchOverlap(supabase, profile.id);
    } catch {
      overlapFailed = true;
    }
    [collection, watchlist] = await Promise.all([
      fetchCollection(supabase, profile.id).catch(() => []),
      fetchWatchlist(supabase, profile.id).catch(() => []),
    ]);
  }

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
              <strong className="font-medium">{counts?.followers ?? "—"}</strong> Followers
            </span>
            <span>
              <strong className="font-medium">{counts?.following ?? "—"}</strong> Following
            </span>
          </div>
        </div>
      </div>

      {profile.bio && <p className="text-(--color-text-primary)">{profile.bio}</p>}

      <FollowButton followerId={user.id} followeeId={profile.id} initialStatus={followStatus} />

      {isLocked ? (
        <LockedProfile username={profile.username} />
      ) : (
        <>
          <section className="flex flex-col gap-3">
            <h2 className="font-semibold text-(--color-text-primary)">Your Venn</h2>
            {overlapFailed ? (
              <p className="text-(--color-text-secondary)">Couldn&apos;t load your Venn.</p>
            ) : overlap && (overlap.viewerTotal > 0 || overlap.otherTotal > 0) ? (
              <VennOverlap
                viewerLabel="Only you"
                otherLabel={`Only @${profile.username}`}
                summary={overlap}
              />
            ) : (
              // Both sides empty: a 0/0 diagram reads as broken rather than
              // as "nothing logged yet". Same copy as PublicProfileView.
              <p className="text-(--color-text-secondary)">
                Log a few things and your shared taste shows up here.
              </p>
            )}
          </section>

          <ProfileShelves
            collection={collection}
            watchlist={watchlist}
            emptyCollection="Nothing logged yet."
            emptyWatchlist="Nothing saved yet."
          />
        </>
      )}
    </main>
  );
}
