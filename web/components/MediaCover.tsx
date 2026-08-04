import type { Media } from "@/lib/media";

interface MediaCoverProps {
  media: Media;
}

/**
 * One cover tile in a profile shelf grid. Ports MediaCoverTile's image
 * state: the artwork when there is one, the title on a plain surface when
 * there isn't. Plain <img> for the same reason as everywhere else on web
 * (see the Phase 3 spec on next/image).
 */
export function MediaCover({ media }: MediaCoverProps) {
  return (
    <div className="flex aspect-[2/3] items-center justify-center overflow-hidden rounded-sm bg-(--color-surface-strong)">
      {media.coverUrl ? (
        // eslint-disable-next-line @next/next/no-img-element -- see the component doc comment
        <img
          src={media.coverUrl}
          alt={media.title}
          loading="lazy"
          className="h-full w-full object-cover"
        />
      ) : (
        <span className="px-2 text-center text-xs text-(--color-text-secondary)">
          {media.title}
        </span>
      )}
    </div>
  );
}
