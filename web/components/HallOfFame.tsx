import Link from "next/link";
import { MediaCover } from "@/components/MediaCover";
import type { HallItem } from "@/lib/hallOfFame";

interface HallOfFameProps {
  items: HallItem[];
  /** Your own profile, which gets a prompt when the hall is empty. */
  isOwner: boolean;
}

/**
 * The handful of things that represent someone, shown before anything
 * else.
 *
 * A profile used to open with the whole collection, which is a record of
 * what someone has got through rather than a statement of what they like —
 * and the two are not the same question. This answers the second one; the
 * collection is still underneath, answering the first.
 *
 * No heading. Twelve covers at the top of a profile do not need to be
 * labelled, and the row of shelf tabs directly beneath already says what
 * the rest of the page is.
 *
 * Renders nothing on someone else's empty hall: a "nothing here yet" on a
 * stranger's profile is a note about our data model, not about them.
 */
export function HallOfFame({ items, isOwner }: HallOfFameProps) {
  if (items.length === 0) {
    if (!isOwner) return null;
    return (
      <p className="text-(--color-text-secondary)">
        Star anything you love to build the top of your profile.
      </p>
    );
  }

  return (
    <ul className="grid grid-cols-3 gap-2 sm:grid-cols-4 lg:grid-cols-6">
      {items.map((item) => (
        <li key={item.postId}>
          <Link href={`/media/${item.media.id}`}>
            <MediaCover media={item.media} />
          </Link>
        </li>
      ))}
    </ul>
  );
}
