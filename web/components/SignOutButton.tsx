"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

/**
 * Ends the session and returns to sign-in.
 *
 * Mirrors iOS's `AuthState.signOut()` in one respect that matters: the
 * local session is cleared and the user is sent to `/login` even if the
 * server call fails. Signing out is an intent, and stranding someone in a
 * signed-in UI because the network blinked is the wrong way to fail —
 * particularly on a shared or borrowed device, which is exactly when
 * someone reaches for this.
 */
export function SignOutButton() {
  const router = useRouter();
  const [signingOut, setSigningOut] = useState(false);

  async function handleSignOut() {
    setSigningOut(true);
    try {
      // scope: "local", not the SDK's "global" default. Signing out of
      // this browser should not end the session on the user's phone.
      await createClient().auth.signOut({ scope: "local" });
    } catch {
      // Deliberately ignored — see the note above.
    }
    // refresh() drops the cached server components holding the old
    // session; without it the nav would still render as signed in.
    router.replace("/login");
    router.refresh();
  }

  return (
    <button
      type="button"
      onClick={() => void handleSignOut()}
      disabled={signingOut}
      className="self-start text-left font-semibold text-red-500 disabled:opacity-50"
    >
      {signingOut ? "Signing out…" : "Sign out"}
    </button>
  );
}
