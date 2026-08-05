import Link from "next/link";
import { LikeButton } from "@/components/LikeButton";

interface PostActionsProps {
  postId: string;
  userId: string;
  likeCount: number;
  likedByMe: boolean;
  commentCount: number;
}

/**
 * The social footer under a feed row: like, and a link through to the
 * post's permalink where the conversation lives.
 */
export function PostActions({
  postId,
  userId,
  likeCount,
  likedByMe,
  commentCount
}: PostActionsProps) {
  return (
    <div className="flex items-center gap-4">
      <LikeButton
        postId={postId}
        userId={userId}
        initialCount={likeCount}
        initialLiked={likedByMe}
      />
      <Link
        href={`/post/${postId}`}
        className="flex items-center gap-1.5 text-sm text-(--color-text-secondary)"
      >
        <span aria-hidden="true">💬</span>
        <span>
          {commentCount > 0 ? commentCount : ""}{" "}
          <span className={commentCount > 0 ? "sr-only" : ""}>
            {commentCount === 1 ? "comment" : "comments"}
          </span>
        </span>
      </Link>
    </div>
  );
}
