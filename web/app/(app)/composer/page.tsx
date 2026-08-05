import { redirect } from "next/navigation";
import { Composer } from "@/components/Composer";
import { MEDIA_KINDS, type MediaKind } from "@/lib/media";
import { createClient } from "@/lib/supabase/server";

interface ComposerPageProps {
  searchParams: Promise<{ kind?: string; q?: string }>;
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
  const { kind, q } = await searchParams;
  const initialKind = kind && MEDIA_KINDS.includes(kind) ? (kind as MediaKind) : undefined;

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col px-4 py-8">
      <Composer userId={user.id} initialKind={initialKind} initialQuery={q ?? ""} />
    </main>
  );
}
