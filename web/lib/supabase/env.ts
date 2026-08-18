/**
 * The two public Supabase values, read defensively.
 *
 * These are pasted into a hosting dashboard by hand, and a bad paste is
 * invisible: the value is a long opaque blob that nobody re-reads. On
 * 2026-08-17 the production `NEXT_PUBLIC_SUPABASE_ANON_KEY` held the key
 * *twice*, separated by a newline. A header value cannot contain a newline,
 * so `fetch` threw `TypeError: Failed to execute 'fetch' on 'Window':
 * Invalid value` before the request left the browser — every sign-in failed
 * with "Couldn't send the magic link", Supabase's own logs showed no
 * request at all, and the service looked healthy because it was. Nobody
 * could sign in or sign up.
 *
 * So: take the first line and trim it. A doubled paste, a trailing newline,
 * or wrapping quotes all stop being outages. This cannot repair a genuinely
 * wrong key — it only removes the ways a *correct* key arrives unusable.
 */

/** First non-empty line, trimmed, with any wrapping quotes removed. */
function firstLine(value: string | undefined, name: string): string {
  if (!value) {
    throw new Error(`${name} is not set. The app cannot reach Supabase without it.`);
  }

  const line = value
    .split(/[\r\n]+/)
    .map((part) => part.trim())
    .find((part) => part.length > 0);

  if (!line) {
    throw new Error(`${name} is set but empty.`);
  }

  return line.replace(/^["']|["']$/g, "");
}

export function supabaseUrl(): string {
  return firstLine(process.env.NEXT_PUBLIC_SUPABASE_URL, "NEXT_PUBLIC_SUPABASE_URL");
}

export function supabaseAnonKey(): string {
  return firstLine(process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY, "NEXT_PUBLIC_SUPABASE_ANON_KEY");
}
