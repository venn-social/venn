import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

/**
 * Magic-link landing page. Mirrors iOS's `AuthService.handleCallback(_:)` —
 * both exchange the PKCE `code` param for a session, same Supabase project,
 * same flow type.
 */
export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url);
  const code = searchParams.get("code");

  if (code) {
    const supabase = await createClient();
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      return NextResponse.redirect(`${origin}/profile`);
    }
  }

  return NextResponse.redirect(`${origin}/login`);
}
