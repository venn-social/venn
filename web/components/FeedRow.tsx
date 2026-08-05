import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import type { FeedPost } from "@/lib/feed";
import { shortRelativeTime } from "@/lib/relativeTime";

interface FeedRowProps {
  post: FeedPost;
  /**
   * The social footer — like button and comment link. Optional so the post
   * detail page can render the row without duplicating the controls it
   * already shows below.
   */
  actions?: React.ReactNode;
}

/**
 * One feed entry, porting ios/Venn/Features/Feed/FeedRow.swift: attribution,
 * a large cover, the title and its metadata, an optional rating, and an
 * optional note.
 */
export function FeedRow({ post, actions }: FeedRowProps) {
  const authorName = post.author.displayName ?? post.author.username;
  // "2023 · Celine Song" — whichever of year / creator is present.
  const metadata = [post.media.year?.toString(), post.media.primaryCreator]
    .filter((part): part is string => Boolean(part))
    .join(" · ");

  return (
    <article className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <Link href={`/${post.author.username}`} className="flex items-center gap-2">
          <Avatar name={authorName} avatarUrl={post.author.avatarUrl} size={28} />
          <span className="text-sm font-medium text-(--color-text-secondary)">
            {authorName} {post.action}
          </span>
        </Link>
        <span className="ml-auto text-xs text-(--color-text-secondary)">
          {shortRelativeTime(post.createdAt)}
        </span>
      </div>

      <div className="flex h-[200px] items-center justify-center overflow-hidden rounded-md bg-(--color-surface-strong)">
        {post.media.coverUrl ? (
          // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
          <img
            src={post.media.coverUrl}
            alt=""
            loading="lazy"
            className="h-full w-full object-cover"
          />
        ) : (
          <span className="px-4 text-center text-(--color-text-secondary)">{post.media.title}</span>
        )}
      </div>

      <div className="flex items-baseline gap-3">
        <div className="flex flex-col gap-0.5">
          <h2 className="text-lg font-semibold text-(--color-text-primary)">{post.media.title}</h2>
          {metadata && <p className="text-sm text-(--color-text-secondary)">{metadata}</p>}
        </div>
        {post.rating !== null && (
          <span className="ml-auto shrink-0 text-sm font-semibold text-(--color-text-primary)">
            <span className="text-(--color-accent)">★</span> {post.rating.toFixed(1)}
          </span>
        )}
      </div>

      {post.caption && <p className="text-(--color-text-secondary)">{post.caption}</p>}

      {actions}
    </article>
  );
}
