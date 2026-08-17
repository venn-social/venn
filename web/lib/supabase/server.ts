import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { supabaseAnonKey, supabaseUrl } from "@/lib/supabase/env";

/**
 * Server-side Supabase client for Server Components, Route Handlers, and
 * Server Actions. Always create a new one per request — never share across
 * requests (see @supabase/ssr's own docs on this).
 *
 * `setAll` can throw when called from a Server Component (cookies are
 * read-only there) — that's fine as long as `proxy.ts` is refreshing the
 * session on every request, which it does.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient(
    supabaseUrl(),
    supabaseAnonKey(),
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, options);
            });
          } catch {
            // Called from a Server Component — proxy.ts refreshes the
            // session instead, so this is safe to ignore.
          }
        },
      },
    }
  );
}
