import { createBrowserClient } from "@supabase/ssr";

/**
 * Browser-side Supabase client. Use from Client Components only — server
 * code (Server Components, Route Handlers, the proxy) uses
 * `lib/supabase/server.ts` instead, which handles cookies differently.
 *
 * Same Supabase project as iOS (see CLAUDE.md rule 17) — just a different
 * SDK talking to it. `NEXT_PUBLIC_*` env vars are safe to expose to the
 * client: this is the anon key, identical in sensitivity to iOS's
 * `SUPABASE_ANON_KEY` in `AppConfig`.
 */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  );
}
