import { redirect } from "next/navigation";
import { Explorer } from "@/components/Explorer";
import { createClient } from "@/lib/supabase/server";

export default async function ExplorerPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col px-4 py-8">
      <Explorer />
    </main>
  );
}
