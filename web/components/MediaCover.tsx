import type { Media } from "@/lib/media";

interface MediaCoverProps {
  media: Media;
}

/**
 * One cover tile, in a profile shelf grid or an Explorer shelf. Ports
 * MediaCoverTile's image state: the artwork when there is one, the title on
 * a plain surface when there isn't. Plain <img> for the same reason as
 * everywhere else on web (see the Phase 3 spec on next/image).
 *
 * Lifts under the cursor, matching the plane. The tile itself grows a
 * little and the artwork inside it grows slightly more, which reads as the
 * cover coming forward rather than the box getting bigger. It rises above
 * its neighbours while it does, or a grid would clip the growth against the
 * next tile along.
 *
 * Pointer-only: `hover` never resolves on a touchscreen, so nothing here
 * costs a phone anything, and the transform is skipped outright for anyone
 * who has asked for less motion.
 *
 * It lifts by exactly one layer, not ten. Enough to clear the tiles beside
 * it, and nowhere near the chrome — an earlier version used the same layer
 * as the nav, so a hovered cover painted straight over it.
 */
export function MediaCover({ media }: MediaCoverProps) {
  return (
    <div className="group relative flex aspect-[2/3] items-center justify-center overflow-hidden rounded-sm bg-(--color-surface-strong) transition-transform duration-200 ease-out hover:z-[1] motion-safe:hover:scale-[1.04]">
      {media.coverUrl ? (
        // eslint-disable-next-line @next/next/no-img-element -- see the component doc comment
        <img
          src={media.coverUrl}
          alt={media.title}
          loading="lazy"
          className="h-full w-full object-cover transition-transform duration-300 ease-out motion-safe:group-hover:scale-[1.06]"
        />
      ) : (
        <span className="px-2 text-center text-xs text-(--color-text-secondary)">
          {media.title}
        </span>
      )}
    </div>
  );
}
