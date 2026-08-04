import { redirect } from "next/navigation";
import { Composer } from "@/components/Composer";
import { createClient } from "@/lib/supabase/server";

export default async function ComposerPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col px-4 py-8">
      <Composer userId={user.id} />
    </main>
  );
}
