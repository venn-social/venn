import { notFound, redirect } from "next/navigation";
import { CommentThread } from "@/components/CommentThread";
import { FeedRow } from "@/components/FeedRow";
import { LikeButton } from "@/components/LikeButton";
import { fetchComments } from "@/lib/comments";
import { fetchLikeInfo } from "@/lib/likes";
import { fetchPost } from "@/lib/post";
import { createClient } from "@/lib/supabase/server";

interface PostPageProps {
  params: Promise<{ id: string }>;
}

/**
 * A single post — the permalink. Until this existed there was no way to
 * link to anything on venn, on either platform.
 */
export default async function PostPage({ params }: PostPageProps) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const post = await fetchPost(supabase, id);
  if (!post) {
    notFound();
  }

  // Likes and comments are independent of each other and of the post, so
  // they load together rather than in sequence.
  const [likeResult, commentResult] = await Promise.allSettled([
    fetchLikeInfo(supabase, [post.id]),
    fetchComments(supabase, post.id)
  ]);

  const like =
    likeResult.status === "fulfilled"
      ? (likeResult.value[post.id] ?? { likeCount: 0, likedByMe: false })
      : { likeCount: 0, likedByMe: false };
  const comments = commentResult.status === "fulfilled" ? commentResult.value : [];

  return (
    <main className="mx-auto flex min-h-screen max-w-lg lg:max-w-2xl flex-col gap-6 px-4 py-8">
      <FeedRow post={post} />

      <div className="flex items-center gap-4 border-y border-(--color-separator) py-3 text-sm">
        <LikeButton
          postId={post.id}
          userId={user.id}
          initialCount={like.likeCount}
          initialLiked={like.likedByMe}
        />
      </div>

      <CommentThread
        postId={post.id}
        userId={user.id}
        postAuthorId={post.author.id}
        initialComments={comments}
      />
    </main>
  );
}
