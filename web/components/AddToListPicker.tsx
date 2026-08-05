"use client";

import { useEffect, useState } from "react";
import {
  addToList,
  fetchListItems,
  fetchListsFor,
  nextPosition,
  type UserList
} from "@/lib/lists";
import { createClient } from "@/lib/supabase/client";

interface AddToListPickerProps {
  userId: string;
  /** Must already exist in public.media — the caller upserts it first. */
  mediaId: string;
}

/**
 * "Also add to a list" — shown after something is logged, so the catalog
 * row already exists and this is a pure append.
 *
 * Loads the user's lists lazily on first open rather than on mount: most
 * logging sessions never touch a list, and fetching them every time would
 * be a query nobody asked for.
 */
export function AddToListPicker({ userId, mediaId }: AddToListPickerProps) {
  const [open, setOpen] = useState(false);
  const [lists, setLists] = useState<UserList[] | null>(null);
  const [added, setAdded] = useState<Record<string, boolean>>({});
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!open || lists !== null) return;

    let cancelled = false;
    fetchListsFor(createClient(), userId)
      .then((loaded) => {
        if (!cancelled) setLists(loaded);
      })
      .catch(() => {
        if (!cancelled) {
          setLists([]);
          setError("Couldn't load your lists.");
        }
      });

    return () => {
      cancelled = true;
    };
  }, [open, lists, userId]);

  async function handleAdd(list: UserList) {
    setBusyId(list.id);
    setError("");
    try {
      const supabase = createClient();
      // Position is read fresh rather than tracked, so two tabs adding to
      // the same list don't both claim the same slot.
      const items = await fetchListItems(supabase, list.id);
      await addToList(supabase, list.id, mediaId, nextPosition(items));
      setAdded((current) => ({ ...current, [list.id]: true }));
    } catch {
      setError("Couldn't add it to that list.");
    } finally {
      setBusyId(null);
    }
  }

  if (!open) {
    return (
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="self-start text-sm font-semibold text-(--color-accent)"
      >
        Also add to a list
      </button>
    );
  }

  return (
    <section className="flex flex-col gap-2 rounded-md bg-(--color-surface) p-3">
      <h3 className="text-sm font-semibold text-(--color-text-primary)">Add to a list</h3>

      {lists === null && <p className="text-sm text-(--color-text-secondary)">Loading…</p>}

      {lists?.length === 0 && (
        <p className="text-sm text-(--color-text-secondary)">
          You don&apos;t have any lists yet.
        </p>
      )}

      {lists?.map((list) => (
        <button
          key={list.id}
          type="button"
          disabled={busyId === list.id || added[list.id]}
          onClick={() => void handleAdd(list)}
          className="flex items-center justify-between text-left text-sm text-(--color-text-primary) disabled:opacity-60"
        >
          <span>{list.title}</span>
          <span className="text-(--color-text-secondary)">
            {added[list.id] ? "Added" : busyId === list.id ? "Adding…" : "Add"}
          </span>
        </button>
      ))}

      {error && <p className="text-sm text-red-500">{error}</p>}
    </section>
  );
}
