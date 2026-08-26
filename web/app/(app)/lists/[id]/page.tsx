import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AddToList } from "@/components/AddToList";
import { ListItemRow } from "@/components/ListItemRow";
import { fetchList, fetchListItems, nextPosition } from "@/lib/lists";
import { fetchProfile } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";

interface ListPageProps {
  params: Promise<{ id: string }>;
}

/**
 * One list. RLS decides whether it's visible at all — a private list simply
 * doesn't come back for anyone but its owner, which surfaces as a 404
 * rather than a "you can't see this", so a private list's existence isn't
 * leaked.
 */
export default async function ListPage({ params }: ListPageProps) {
  const { id } = await params;
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const list = await fetchList(supabase, id);
  if (!list) {
    notFound();
  }

  const [items, owner] = await Promise.all([
    fetchListItems(supabase, list.id).catch(() => []),
    fetchProfile(supabase, list.ownerId).catch(() => null)
  ]);

  const isOwner = list.ownerId === user.id;

  return (
    <main className="mx-auto flex min-h-screen max-w-lg lg:max-w-2xl flex-col gap-6 px-4 py-8">
      <div className="flex flex-col gap-2">
        <div className="flex items-center gap-2">
          <h1 className="text-xl font-semibold text-(--color-text-primary)">{list.title}</h1>
          {!list.isPublic && (
            <span className="rounded-pill bg-(--color-surface-strong) px-2 py-0.5 text-xs text-(--color-text-secondary)">
              Private
            </span>
          )}
        </div>

        {list.description && (
          <p className="text-(--color-text-secondary)">{list.description}</p>
        )}

        {owner && (
          <p className="text-sm text-(--color-text-secondary)">
            by{" "}
            <Link href={`/${owner.username}`} className="font-medium">
              @{owner.username}
            </Link>
          </p>
        )}
      </div>

      {items.length === 0 ? (
        <p className="text-(--color-text-secondary)">Nothing in this list yet.</p>
      ) : (
        <ul className="flex flex-col gap-3">
          {items.map((item) => (
            <li key={item.media.id}>
              <ListItemRow listId={list.id} item={item} items={items} canEdit={isOwner} />
            </li>
          ))}
        </ul>
      )}

      {isOwner && (
        <div className="border-t border-(--color-separator) pt-6">
          {/* Appending to the end — position is explicit so the maker's
              order survives, and drag-to-reorder can land later. */}
          <AddToList listId={list.id} nextPosition={nextPosition(items)} />
        </div>
      )}
    </main>
  );
}
