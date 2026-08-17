import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { hasProfile } from "@/lib/onboarding";
import {
  hasCompletionCookie,
  isExemptPath,
  PROFILE_COOKIE,
  PROFILE_COOKIE_MAX_AGE
} from "@/lib/onboardingGate";
import { supabaseAnonKey, supabaseUrl } from "@/lib/supabase/env";

/**
 * Refreshes the Supabase session cookie on every request, and gates a
 * signed-in-but-profile-less user to /onboarding — the centralized
 * equivalent of iOS's OnboardingGate. See
 * docs/superpowers/specs/2026-08-04-web-onboarding-design.md.
 *
 * Called from the root `proxy.ts` (Next.js 16 renamed `middleware.ts` to
 * `proxy.ts`), which runs on every request its matcher covers — so this
 * can't be bypassed by deep-linking directly to /[username] or /requests.
 *
 * The profile lookup is skipped once a cookie vouches for the current user
 * (see lib/onboardingGate.ts). Without that, this ran a Postgres query on
 * every single request from every signed-in user, to answer a question that
 * changes once per account and never changes back.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    supabaseUrl(),
    supabaseAnonKey(),
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        }
      }
    }
  );

  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user || isExemptPath(request.nextUrl.pathname)) {
    return response;
  }

  // The cheap path: this user already has a profile, established once.
  if (hasCompletionCookie(request.cookies.get(PROFILE_COOKIE)?.value, user.id)) {
    return response;
  }

  const complete = await hasProfile(supabase, user.id);

  if (!complete) {
    const redirect = NextResponse.redirect(new URL("/onboarding", request.url));
    // Clear any cookie left by a previous account on this browser.
    redirect.cookies.delete(PROFILE_COOKIE);
    return redirect;
  }

  // Remember it, so this is the last lookup for this user on this browser.
  response.cookies.set(PROFILE_COOKIE, user.id, {
    httpOnly: true,
    sameSite: "lax",
    secure: process.env.NODE_ENV === "production",
    maxAge: PROFILE_COOKIE_MAX_AGE,
    path: "/"
  });

  return response;
}
