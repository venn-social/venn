import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { MediaCover } from "@/components/MediaCover";
import { fetchList, fetchListItems } from "@/lib/lists";
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

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-6 px-4 py-8">
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
        <p className="text-(--color-text-secondary)">
          Nothing in this list yet.{" "}
          {list.ownerId === user.id && "Add things from a title's page as you log them."}
        </p>
      ) : (
        <ul className="grid grid-cols-3 gap-2">
          {items.map((item) => (
            <li key={item.media.id} className="flex flex-col gap-1">
              <MediaCover media={item.media} />
              {item.note && (
                <p className="text-xs text-(--color-text-secondary)">{item.note}</p>
              )}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
