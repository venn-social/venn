import { redirect } from "next/navigation";
import { ProfileEditForm } from "@/components/ProfileEditForm";
import { fetchProfile } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";

export default async function ProfileEditPage() {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const profile = await fetchProfile(supabase, user.id);
  if (!profile) {
    redirect("/onboarding");
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-lg flex-col px-4 py-8">
      <ProfileEditForm
        userId={user.id}
        initialDisplayName={profile.displayName ?? ""}
        initialBio={profile.bio ?? ""}
      />
    </main>
  );
}
