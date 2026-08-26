import Link from "next/link";
import { redirect } from "next/navigation";
import { CreateListForm } from "@/components/CreateListForm";
import { fetchListsFor } from "@/lib/lists";
import { createClient } from "@/lib/supabase/server";

/** Your own lists, plus the form to start another. */
export default async function ListsPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  let lists;
  try {
    lists = await fetchListsFor(supabase, user.id);
  } catch {
    return (
      <main className="mx-auto flex min-h-screen max-w-lg lg:max-w-2xl flex-col gap-4 px-4 py-8">
        <h1 className="text-xl font-semibold text-(--color-text-primary)">Lists</h1>
        <p className="text-(--color-text-secondary)">Couldn&apos;t load your lists.</p>
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-lg lg:max-w-2xl flex-col gap-6 px-4 py-8">
      <div className="flex flex-col gap-1">
        <h1 className="text-xl font-semibold text-(--color-text-primary)">Lists</h1>
        <p className="text-(--color-text-secondary)">
          Group things however you like — a year, a mood, a recommendation you keep repeating.
        </p>
      </div>

      {lists.length === 0 ? (
        <p className="text-(--color-text-secondary)">No lists yet. Make your first one below.</p>
      ) : (
        <ul className="flex flex-col divide-y divide-(--color-separator)">
          {lists.map((list) => (
            <li key={list.id}>
              <Link href={`/lists/${list.id}`} className="flex flex-col gap-0.5 py-3">
                <span className="flex items-center gap-2">
                  <span className="font-medium text-(--color-text-primary)">{list.title}</span>
                  {!list.isPublic && (
                    <span className="rounded-pill bg-(--color-surface-strong) px-2 py-0.5 text-xs text-(--color-text-secondary)">
                      Private
                    </span>
                  )}
                </span>
                {list.description && (
                  <span className="text-sm text-(--color-text-secondary)">{list.description}</span>
                )}
              </Link>
            </li>
          ))}
        </ul>
      )}

      <section className="flex flex-col gap-3 border-t border-(--color-separator) pt-6">
        <h2 className="font-semibold text-(--color-text-primary)">New list</h2>
        <CreateListForm userId={user.id} />
      </section>
    </main>
  );
}
