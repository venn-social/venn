import Link from "next/link";
import { Avatar } from "@/components/Avatar";
import { FeedItemMenu } from "@/components/FeedItemMenu";
import { StarIcon } from "@/components/Icon";
import type { FeedPost } from "@/lib/feed";
import { shortRelativeTime } from "@/lib/relativeTime";

interface FeedRowProps {
  post: FeedPost;
  /**
   * The signed-in user, so the artwork can offer Log / Add to Watchlist.
   * Omitted (or equal to the author) means no menu.
   */
  viewerId?: string | null;
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
export function FeedRow({ post, actions, viewerId = null }: FeedRowProps) {
  const authorName = post.author.displayName ?? post.author.username;
  // "2023 · Celine Song" — whichever of year / creator is present.
  const metadata = [post.media.year?.toString(), post.media.primaryCreator]
    .filter((part): part is string => Boolean(part))
    .join(" · ");

  return (
    <article className="flex flex-col gap-3">
      <div className="flex items-center gap-2">
        <Link href={`/${post.author.username}`} className="group flex items-center gap-2">
          <Avatar name={authorName} avatarUrl={post.author.avatarUrl} size={28} />
          <span className="text-sm">
            {/* Accent is this design system's signal for "interactive", and
                the name being a link to a profile was previously invisible —
                it read as the same grey as the verb after it. */}
            <span className="font-semibold text-(--color-accent) group-hover:underline">
              {authorName}
            </span>{" "}
            <span className="text-(--color-text-secondary)">{post.action}</span>
          </span>
        </Link>
        <span className="ml-auto text-xs text-(--color-text-secondary)">
          {shortRelativeTime(post.createdAt)}
        </span>
      </div>

      <div className="group relative">
        {/* Mounted only when it has something to offer — a menu that
            renders null still runs its hooks, which made every feed test
            need a router it never used. */}
        {viewerId && viewerId !== post.author.id && (
          <FeedItemMenu mediaId={post.media.id} mediaTitle={post.media.title} viewerId={viewerId} />
        )}
        <Link
          href={`/media/${post.media.id}`}
          // No fixed height, and nothing cropped. Artwork arrives in every
          // shape there is — a square sleeve, a tall poster, a wide still —
          // and forcing them all through one letterbox threw away the part
          // of the image that made it worth looking at. The feed is as
          // uneven as the things in it.
          //
          // The minimum is for the other case: a cover whose URL has died
          // renders at zero height and takes the whole card down to a line
          // of text. Losing the picture is unavoidable; losing the post is
          // not.
          className="flex min-h-[120px] items-center justify-center overflow-hidden rounded-md bg-(--color-surface-strong)"
        >
          {post.media.coverUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
            <img src={post.media.coverUrl} alt="" loading="lazy" className="h-auto w-full" />
          ) : (
            <span className="px-4 py-10 text-center text-(--color-text-secondary)">
              {post.media.title}
            </span>
          )}
        </Link>
      </div>

      <div className="flex items-baseline gap-3">
        <div className="flex flex-col gap-0.5">
          <Link href={`/media/${post.media.id}`}>
            <h2 className="text-lg font-semibold text-(--color-text-primary)">
              {post.media.title}
            </h2>
          </Link>
          {metadata && <p className="text-sm text-(--color-text-secondary)">{metadata}</p>}
        </div>
        {post.rating !== null && (
          <span className="ml-auto flex shrink-0 items-center gap-1 text-sm font-semibold text-(--color-text-primary)">
            <StarIcon size={14} className="text-(--color-accent)" /> {post.rating.toFixed(1)}
          </span>
        )}
      </div>

      {post.caption && <p className="text-(--color-text-secondary)">{post.caption}</p>}

      {actions}
    </article>
  );
}
