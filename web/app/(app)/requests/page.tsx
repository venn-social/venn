import { redirect } from "next/navigation";
import { RequestsList } from "@/components/RequestsList";
import { fetchPendingRequests } from "@/lib/follow";
import { createClient } from "@/lib/supabase/server";

export default async function RequestsPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const requests = await fetchPendingRequests(supabase, user.id);

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Follow Requests</h1>
      <RequestsList initialRequests={requests} />
    </main>
  );
}
