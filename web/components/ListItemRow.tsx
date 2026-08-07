"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { MediaCover } from "@/components/MediaCover";
import type { ListItem } from "@/lib/lists";
import { ChevronDownIcon, ChevronUpIcon } from "@/components/Icon";
import { movedOrder, removeFromList, reorderList } from "@/lib/lists";
import { mediaMetadata } from "@/lib/media";
import { createClient } from "@/lib/supabase/client";

interface ListItemRowProps {
  listId: string;
  item: ListItem;
  /** Every item in the list, in order — needed to compute a move. */
  items: ListItem[];
  /** Only the list's owner sees the remove and move controls. */
  canEdit: boolean;
}

export function ListItemRow({ listId, item, items, canEdit }: ListItemRowProps) {
  const router = useRouter();
  const [removing, setRemoving] = useState(false);
  const [moving, setMoving] = useState(false);
  const metadata = mediaMetadata(item.media);

  const index = items.findIndex((candidate) => candidate.media.id === item.media.id);
  const isFirst = index === 0;
  const isLast = index === items.length - 1;

  async function handleMove(direction: "up" | "down") {
    setMoving(true);
    try {
      await reorderList(createClient(), listId, movedOrder(items, item.media.id, direction));
      router.refresh();
    } catch {
      // The order stays as it was. RLS refuses a reorder that is not the
      // owner's, and a transient failure should not scramble the list.
    } finally {
      setMoving(false);
    }
  }

  async function handleRemove() {
    setRemoving(true);
    try {
      await removeFromList(createClient(), listId, item.media.id);
      router.refresh();
    } catch {
      // The row stays put; RLS would have refused a removal that isn't
      // the owner's, and a transient failure shouldn't lose the item.
      setRemoving(false);
    }
  }

  return (
    <div className="flex items-center gap-3">
      <Link href={`/media/${item.media.id}`} className="w-[44px] shrink-0">
        <MediaCover media={item.media} />
      </Link>

      <div className="flex flex-col gap-0.5">
        <Link href={`/media/${item.media.id}`}>
          <span className="font-medium text-(--color-text-primary)">{item.media.title}</span>
        </Link>
        {metadata && <span className="text-sm text-(--color-text-secondary)">{metadata}</span>}
        {item.note && <span className="text-sm text-(--color-text-secondary)">{item.note}</span>}
      </div>

      {canEdit && (
        <div className="ml-auto flex items-center gap-1">
          {/* Hidden rather than disabled at the ends: a control that can
              never do anything is noise, and the list's shape already says
              why. */}
          {!isFirst && (
            <button
              type="button"
              onClick={() => void handleMove("up")}
              disabled={moving}
              aria-label={`Move ${item.media.title} up`}
              className="p-1 text-(--color-text-secondary) hover:text-(--color-text-primary) disabled:opacity-50"
            >
              <ChevronUpIcon size={16} />
            </button>
          )}
          {!isLast && (
            <button
              type="button"
              onClick={() => void handleMove("down")}
              disabled={moving}
              aria-label={`Move ${item.media.title} down`}
              className="p-1 text-(--color-text-secondary) hover:text-(--color-text-primary) disabled:opacity-50"
            >
              <ChevronDownIcon size={16} />
            </button>
          )}
          <button
            type="button"
            onClick={() => void handleRemove()}
            disabled={removing}
            className="text-sm text-(--color-text-secondary) hover:text-red-500 disabled:opacity-50"
          >
            Remove
          </button>
        </div>
      )}
    </div>
  );
}
