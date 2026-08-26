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
    // The whole post is the width of its artwork, and centred. Insetting
    // only the cover left the attribution, title and rating running wider
    // than the thing they describe, which read as two elements that
    // happened to be near each other rather than one post.
    <article className="mx-auto flex w-[72%] flex-col gap-3">
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
          // Square, and the full width of the post — which is itself
          // inset, so this is where the post's width is actually decided.
          className="flex aspect-square w-full items-center justify-center overflow-hidden rounded-md bg-(--color-surface-strong)"
        >
          {post.media.coverUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
            <img
              src={post.media.coverUrl}
              alt=""
              loading="lazy"
              // Which part of a portrait cover survives the square.
              //
              // Detecting where the title sits in the artwork would need the
              // image analysed — OCR or saliency on a canvas, cross-origin,
              // per image, before first paint — which is a great deal of
              // machinery for a guess. The kind is a free approximation:
              // posters and jackets put their art above and their title
              // along the bottom, and venn prints the title underneath the
              // cover anyway, so keeping the art loses nothing that is not
              // already on the screen in a more legible form. Album sleeves
              // are square to begin with and lose nothing either way.
              className={`h-full w-full object-cover ${
                post.media.kind === "album" ? "object-center" : "object-top"
              }`}
            />
          ) : (
            <span className="px-4 text-center text-(--color-text-secondary)">
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
