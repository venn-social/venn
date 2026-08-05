"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { MediaCover } from "@/components/MediaCover";
import type { ListItem } from "@/lib/lists";
import { removeFromList } from "@/lib/lists";
import { mediaMetadata } from "@/lib/media";
import { createClient } from "@/lib/supabase/client";

interface ListItemRowProps {
  listId: string;
  item: ListItem;
  /** Only the list's owner sees the remove control. */
  canEdit: boolean;
}

export function ListItemRow({ listId, item, canEdit }: ListItemRowProps) {
  const router = useRouter();
  const [removing, setRemoving] = useState(false);
  const metadata = mediaMetadata(item.media);

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
      <div className="w-[44px] shrink-0">
        <MediaCover media={item.media} />
      </div>

      <div className="flex flex-col gap-0.5">
        <span className="font-medium text-(--color-text-primary)">{item.media.title}</span>
        {metadata && <span className="text-sm text-(--color-text-secondary)">{metadata}</span>}
        {item.note && <span className="text-sm text-(--color-text-secondary)">{item.note}</span>}
      </div>

      {canEdit && (
        <button
          type="button"
          onClick={() => void handleRemove()}
          disabled={removing}
          className="ml-auto text-sm text-(--color-text-secondary) hover:text-red-500 disabled:opacity-50"
        >
          Remove
        </button>
      )}
    </div>
  );
}
