import Link from "next/link";
import { redirect } from "next/navigation";
import { PrivacyToggle } from "@/components/PrivacyToggle";
import { fetchProfile } from "@/lib/profile";
import { createClient } from "@/lib/supabase/server";

/**
 * Account settings, porting SettingsView.swift. Just the private-account
 * toggle today, same as iOS — it grows as more settings land.
 */
export default async function SettingsPage() {
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
    <main className="mx-auto flex min-h-screen max-w-lg flex-col gap-4 px-4 py-8">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Settings</h1>

      <PrivacyToggle userId={user.id} initialIsPrivate={profile.isPrivate} />

      {profile.isPrivate && (
        <Link href="/requests" className="font-semibold text-(--color-accent)">
          Follow requests
        </Link>
      )}
    </main>
  );
}
