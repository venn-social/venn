import { redirect } from "next/navigation";
import { OnboardingFlow } from "@/components/OnboardingFlow";
import { hasProfile } from "@/lib/onboarding";
import { createClient } from "@/lib/supabase/server";

export default async function OnboardingPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const complete = await hasProfile(supabase, user.id);
  if (complete) {
    redirect("/profile");
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-sm flex-col justify-center px-4 py-8">
      <OnboardingFlow userId={user.id} />
    </main>
  );
}