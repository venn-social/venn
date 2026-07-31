import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * Refreshes the Supabase session cookie on every request. Required
 * whenever `setAll` can't run from a Server Component (see server.ts) —
 * without this, sessions silently expire mid-visit. Called from the root
 * `proxy.ts` (Next.js 16 renamed `middleware.ts` to `proxy.ts`).
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

  // Touches the session so expired tokens refresh — the return value
  // itself isn't used here since route-level redirects (see app/profile)
  // handle the signed-out case.
  await supabase.auth.getUser();

  return response;
}
