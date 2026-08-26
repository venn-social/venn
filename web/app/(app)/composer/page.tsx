import { redirect } from "next/navigation";
import { Composer } from "@/components/Composer";
import { candidateFromMedia } from "@/lib/catalog/types";
import { MEDIA_KINDS, type MediaKind } from "@/lib/media";
import { fetchMediaById } from "@/lib/mediaDetail";
import { createClient } from "@/lib/supabase/server";

interface ComposerPageProps {
  searchParams: Promise<{ kind?: string; q?: string; mediaId?: string }>;
}

export default async function ComposerPage({ searchParams }: ComposerPageProps) {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  // Explorer links here with a prefill; anything unrecognised falls back to
  // the default rather than putting the composer in an impossible state.
  const { kind, q, mediaId } = await searchParams;
  const initialKind = kind && MEDIA_KINDS.includes(kind) ? (kind as MediaKind) : undefined;

  // Arriving from a title's own page, where the thing to log is already
  // decided. Searching for it again and asking the user to pick it out of
  // the results is a question they have just answered.
  let initialPicked = null;
  if (mediaId) {
    const media = await fetchMediaById(supabase, mediaId);
    initialPicked = media ? candidateFromMedia(media) : null;
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-lg lg:max-w-2xl flex-col px-4 py-8">
      <Composer
        userId={user.id}
        initialKind={initialKind}
        initialQuery={q ?? ""}
        initialPicked={initialPicked}
      />
    </main>
  );
}
