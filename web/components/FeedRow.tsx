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
   * Like and comment, laid over the bottom of the artwork.
   *
   * Optional: the post detail page renders the row without them, because it
   * already shows the same controls under it.
   */
  overlay?: React.ReactNode;
  /**
   * The foot of the post — in practice the comment thread, once expanded.
   * It cannot live in the overlay with the controls that open it: a thread
   * is arbitrarily tall and would cover the artwork it belongs to.
   */
  actions?: React.ReactNode;
}

/**
 * One feed entry, porting ios/Venn/Features/Feed/FeedRow.swift: attribution,
 * a large cover, the title and its metadata, an optional rating, and an
 * optional note.
 */
export function FeedRow({ post, actions, overlay, viewerId = null }: FeedRowProps) {
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
    <article className="mx-auto flex w-[72%] flex-col gap-2">
      <div className="flex items-center gap-2">
        <Link href={`/${post.author.username}`} className="group flex items-center gap-1.5">
          <Avatar name={authorName} avatarUrl={post.author.avatarUrl} size={22} />
          <span className="text-xs">
            {/* Accent is this design system's signal for "interactive", and
                the name being a link to a profile was previously invisible —
                it read as the same grey as the verb after it. */}
            <span className="font-semibold text-(--color-accent) group-hover:underline">
              {authorName}
            </span>{" "}
            <span className="text-(--color-text-secondary)">{post.action}</span>
          </span>
        </Link>
        <span className="ml-auto text-[11px] text-(--color-text-secondary)">
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
        {/* A second, shorter scrim at the top. It carries the rating, and
            it is also what lets the ⋯ drop its black pill: both sit on it
            rather than on whatever the artwork happens to be. */}
        <div className="pointer-events-none absolute inset-x-0 top-0 z-[1] flex h-14 items-start justify-end rounded-t-md bg-gradient-to-b from-black/55 to-transparent p-2">
          {post.rating !== null && (
            <span className="flex shrink-0 items-center gap-1 text-xs font-semibold tabular-nums text-white drop-shadow-[0_1px_3px_rgb(0_0_0/0.6)]">
              <StarIcon size={12} className="text-(--color-accent)" />
              {post.rating.toFixed(1)}
            </span>
          )}
        </div>
        <Link
          href={`/media/${post.media.id}`}
          // The title used to be a second link underneath. Now that it is
          // printed on the artwork, this is the only link to the detail
          // page — so it has to carry the name the title used to give it.
          aria-label={post.media.title}
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
              // along the bottom — which venn now prints over that same
              // bottom edge, so cropping it away is what stops a cover
              // naming itself twice. Album sleeves are square to begin
              // with and lose nothing either way.
              className={`h-full w-full object-cover ${
                post.media.kind === "album" ? "object-center" : "object-top"
              }`}
            />
          ) : null}
        </Link>
        {/* Everything the post says about the title now sits on the title.
            Legibility without analysing the image: a scrim dark enough for
            white to survive a pale cover, and a drop shadow for the covers
            that are pale *and* busy. The band is click-through so the
            artwork underneath still opens; only the controls take the
            pointer.

            Re-pointing the two text tokens is what recolours the controls.
            They are plain CSS variables, so a local declaration reaches
            LikeButton and the comment button without either needing to
            know it is being rendered over a photograph. */}
        <div
          className="pointer-events-none absolute inset-x-0 bottom-0 flex flex-col gap-0.5
            rounded-b-md bg-gradient-to-t from-black/85 via-black/45 to-transparent p-3 pt-14
            text-white drop-shadow-[0_1px_3px_rgb(0_0_0/0.6)]
            [--color-text-primary:#fff] [--color-text-secondary:rgb(255_255_255/0.95)]"
        >
          {/* One line each. A cover is a fixed height and a long title is
              not, so the alternative to clamping is a scrim that grows
              until it swallows the artwork it is captioning. */}
          <h2 className="line-clamp-1 text-sm font-semibold">{post.media.title}</h2>
          {(metadata || overlay) && (
            <div className="flex items-center gap-1.5 text-xs">
              {metadata && <p className="line-clamp-1 text-white/70">{metadata}</p>}
              {overlay && <div className="pointer-events-auto ml-auto">{overlay}</div>}
            </div>
          )}
        </div>
      </div>

      {post.caption && <p className="text-sm text-(--color-text-secondary)">{post.caption}</p>}

      {actions}
    </article>
  );
}
