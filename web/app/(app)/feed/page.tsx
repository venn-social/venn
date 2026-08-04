import { redirect } from "next/navigation";
import { FeedPagination } from "@/components/FeedPagination";
import { FeedRow } from "@/components/FeedRow";
import { FEED_PAGE_SIZE, fetchFeedPage } from "@/lib/feed";
import { createClient } from "@/lib/supabase/server";

/**
 * The feed — posts from people you follow, plus your own. Mirrors
 * ios/Venn/Features/Feed/FeedView.swift. The first page is rendered here
 * on the server; <FeedPagination> takes over for infinite scroll.
 */
export default async function FeedPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  let posts;
  try {
    posts = await fetchFeedPage(supabase, { limit: FEED_PAGE_SIZE });
  } catch {
    return (
      <main className="mx-auto flex max-w-lg flex-col gap-4 px-4 py-8">
        <p className="text-(--color-text-secondary)">Couldn&apos;t load the feed.</p>
      </main>
    );
  }

  if (posts.length === 0) {
    // iOS's title and first sentence. Its second sentence points at the
    // Explorer tab and the composer, neither of which exists on web yet —
    // restored when they ship (docs/TECH_DEBT.md).
    return (
      <main className="mx-auto flex max-w-lg flex-col gap-2 px-4 py-16 text-center">
        <h1 className="text-lg font-semibold text-(--color-text-primary)">Quiet for now</h1>
        <p className="text-(--color-text-secondary)">Your feed shows people you follow.</p>
      </main>
    );
  }

  const lastPost = posts[posts.length - 1];

  return (
    <main className="mx-auto flex max-w-lg flex-col gap-10 px-4 py-8">
      {posts.map((post) => (
        <FeedRow key={post.id} post={post} />
      ))}
      <FeedPagination
        initialCursor={lastPost.createdAt.toISOString()}
        initialHasMore={posts.length >= FEED_PAGE_SIZE}
      />
    </main>
  );
}
