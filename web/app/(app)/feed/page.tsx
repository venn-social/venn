import { redirect } from "next/navigation";
import { FeedColumns } from "@/components/FeedColumns";
import { FeedModeShell } from "@/components/FeedModeShell";
import { FeedPagination } from "@/components/FeedPagination";
import { FeedRow } from "@/components/FeedRow";
import { SpatialFeed } from "@/components/SpatialFeed";
import { PostActions } from "@/components/PostActions";
import { fetchCommentCounts } from "@/lib/comments";
import { fetchLikeInfo } from "@/lib/likes";
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
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  let posts;
  try {
    posts = await fetchFeedPage(supabase, { limit: FEED_PAGE_SIZE });
  } catch {
    return (
      <main className="mx-auto flex max-w-lg lg:max-w-2xl flex-col gap-4 px-4 py-8">
        <p className="text-(--color-text-secondary)">Couldn&apos;t load the feed.</p>
      </main>
    );
  }

  if (posts.length === 0) {
    // iOS's title and first sentence. Its second sentence points at the
    // Explorer tab and the composer, neither of which exists on web yet —
    // restored when they ship (docs/TECH_DEBT.md).
    return (
      <main className="mx-auto flex max-w-lg lg:max-w-2xl flex-col gap-2 px-4 py-16 text-center">
        <h1 className="text-lg font-semibold text-(--color-text-primary)">Quiet for now</h1>
        <p className="text-(--color-text-secondary)">Your feed shows people you follow.</p>
      </main>
    );
  }

  const lastPost = posts[posts.length - 1];

  // One call each for the whole page rather than per row — 20 posts would
  // otherwise be 40 extra round trips. Social counts are non-critical, so a
  // failure renders the feed without them instead of failing the page.
  const postIds = posts.map((post) => post.id);
  const [likeResult, commentResult] = await Promise.allSettled([
    fetchLikeInfo(supabase, postIds),
    fetchCommentCounts(supabase, postIds)
  ]);
  const likes = likeResult.status === "fulfilled" ? likeResult.value : {};
  const commentCounts = commentResult.status === "fulfilled" ? commentResult.value : {};

  return (
    <FeedModeShell
      plane={
        <SpatialFeed
          initialPosts={posts}
          initialCursor={lastPost.createdAt.toISOString()}
          initialHasMore={posts.length >= FEED_PAGE_SIZE}
        />
      }
    >
      {/* Extra room at the foot: the layout switch floats over the page,
          and without it the switch would sit on top of the last post. */}
      <main className="mx-auto flex max-w-lg flex-col gap-8 px-4 pt-8 pb-28 lg:max-w-4xl">
        <FeedColumns>
          {posts.map((post) => (
            <FeedRow
              key={post.id}
              post={post}
              viewerId={user.id}
              actions={
                <PostActions
                  postId={post.id}
                  userId={user.id}
                  postAuthorId={post.author.id}
                  likeCount={likes[post.id]?.likeCount ?? 0}
                  likedByMe={likes[post.id]?.likedByMe ?? false}
                  commentCount={commentCounts[post.id] ?? 0}
                />
              }
            />
          ))}
        </FeedColumns>

        <FeedPagination
          viewerId={user.id}
          initialCursor={lastPost.createdAt.toISOString()}
          initialHasMore={posts.length >= FEED_PAGE_SIZE}
        />
      </main>
    </FeedModeShell>
  );
}
