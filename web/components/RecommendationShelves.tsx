import Link from "next/link";
import { MediaCover } from "@/components/MediaCover";
import { shelfTitle } from "@/lib/recommendationCopy";
import type { Shelf, ShelfItem } from "@/lib/recommendations";

interface RecommendationShelvesProps {
  shelves: Shelf[];
}

/**
 * The recommendation shelves, above Explorer's browse grid.
 *
 * Renders nothing when there are no shelves rather than an empty state:
 * the browse grid below is already a reasonable thing to look at, and a
 * "no recommendations yet" message would be noise on top of it.
 */
export function RecommendationShelves({ shelves }: RecommendationShelvesProps) {
  if (shelves.length === 0) return null;

  return (
    <div className="flex flex-col gap-6">
      {shelves.map((shelf) => (
        <section key={`${shelf.source}-${shelf.seedTitle ?? ""}`} className="flex flex-col gap-2">
          <h2 className="font-semibold text-(--color-text-primary)">{shelfTitle(shelf)}</h2>
          <ul className="flex gap-3 overflow-x-auto pb-1">
            {shelf.items.map((item) => (
              <li key={itemKey(item)} className="w-[110px] shrink-0">
                <ShelfCard item={item} />
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  );
}

/**
 * A catalog result is not in `public.media` yet, so it has no detail page
 * to open — it goes to the composer prefilled instead, which is also the
 * action someone wants after seeing something they like.
 */
function ShelfCard({ item }: { item: ShelfItem }) {
  if (item.kind === "media") {
    return (
      <Link href={`/media/${item.media.id}`} className="flex flex-col gap-1">
        <MediaCover media={item.media} />
        <span className="line-clamp-2 text-xs text-(--color-text-secondary)">
          {item.media.title}
        </span>
      </Link>
    );
  }

  const { candidate } = item;
  return (
    <Link
      href={`/composer?kind=${candidate.kind}&q=${encodeURIComponent(candidate.title)}`}
      className="flex flex-col gap-1"
    >
      <div className="flex h-[165px] items-center justify-center overflow-hidden rounded-md bg-(--color-surface-strong)">
        {candidate.coverUrl ? (
          // eslint-disable-next-line @next/next/no-img-element -- see the Phase 3 spec on next/image
          <img
            src={candidate.coverUrl}
            alt=""
            loading="lazy"
            className="h-full w-full object-cover"
          />
        ) : (
          <span className="px-2 text-center text-xs text-(--color-text-secondary)">
            {candidate.title}
          </span>
        )}
      </div>
      <span className="line-clamp-2 text-xs text-(--color-text-secondary)">{candidate.title}</span>
    </Link>
  );
}

function itemKey(item: ShelfItem): string {
  return item.kind === "media" ? item.media.id : item.candidate.id;
}
