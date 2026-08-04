import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { hasProfile } from "@/lib/onboarding";

/**
 * Paths a signed-in user is never redirected away from by the onboarding
 * check below — /onboarding itself (it IS the destination), /login and
 * /auth/callback (auth is still in flight, no user to check yet in
 * practice, but excluded defensively).
 */
const ONBOARDING_EXEMPT_PATHS = ["/onboarding", "/login", "/auth/callback"];

/**
 * Refreshes the Supabase session cookie on every request, and gates a
 * signed-in-but-profile-less user to /onboarding — the centralized
 * equivalent of iOS's OnboardingGate. See
 * docs/superpowers/specs/2026-08-04-web-onboarding-design.md.
 *
 * Called from the root `proxy.ts` (Next.js 16 renamed `middleware.ts` to
 * `proxy.ts`), which runs on every request its matcher covers — so this
 * can't be bypassed by deep-linking directly to /[username] or /requests.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
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
        },
      },
    }
  );

  const {
    data: { user }
  } = await supabase.auth.getUser();

  const isExempt = ONBOARDING_EXEMPT_PATHS.some((path) =>
    request.nextUrl.pathname.startsWith(path)
  );

  if (user && !isExempt) {
    const complete = await hasProfile(supabase, user.id);
    if (!complete) {
      return NextResponse.redirect(new URL("/onboarding", request.url));
    }
  }

  return response;
}
