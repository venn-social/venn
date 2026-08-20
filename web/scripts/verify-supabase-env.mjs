/**
 * Refuse to build against Supabase credentials that cannot work.
 *
 * `NEXT_PUBLIC_*` values are inlined at build time, so the anon key that
 * ships to the browser is decided here and nowhere else. That is why this
 * check lives in the build rather than in CI: CI sees the repository's
 * secrets, and the value that actually broke production was the one in the
 * hosting dashboard, which CI never reads.
 *
 * On 2026-08-17 the deployed `NEXT_PUBLIC_SUPABASE_ANON_KEY` held the key
 * twice with a newline between the copies. A header value cannot contain a
 * newline, so every `fetch` threw before leaving the browser, nobody could
 * sign in, and Supabase's logs showed nothing at all because nothing ever
 * arrived. `lib/supabase/env.ts` now tolerates that particular shape; this
 * catches the ones tolerance cannot fix — a key for the wrong project, an
 * expired key, a truncated key, a URL and key that disagree.
 *
 * Deliberately dependency-free and offline: it decodes the JWT the key
 * already is, and compares it against the URL. It never contacts Supabase,
 * so it cannot make a build flaky or slow.
 */

// CommonJS module, so it has no named exports from ESM.
import nextEnv from "@next/env";
const { loadEnvConfig } = nextEnv;

// Read .env / .env.local the way `next build` does. Without this the check
// would see a bare process.env and fail on every local build, while the
// build it guards would have found the values perfectly well.
loadEnvConfig(process.cwd());

/** The first non-empty line, trimmed, unquoted. Mirrors lib/supabase/env.ts. */
function firstLine(value) {
  if (!value) return null;
  const line = value
    .split(/[\r\n]+/)
    .map((part) => part.trim())
    .find((part) => part.length > 0);
  return line ? line.replace(/^["']|["']$/g, "") : null;
}

function fail(problem, remedy) {
  console.error(`\n✗ Supabase environment is unusable: ${problem}\n  ${remedy}\n`);
  process.exit(1);
}

/**
 * Say so when a value only works because it was repaired.
 *
 * `firstLine` makes a doubled paste harmless, which is the point — but
 * harmless is not the same as correct, and a silent safety net is one
 * nobody ever removes. Warn rather than fail: the build genuinely does
 * work, and breaking deploys over a variable that has already been made
 * safe would be the wrong trade.
 */
function warnIfRepaired(name, raw, used) {
  if (raw === undefined || raw === used) return;
  console.warn(
    `\n⚠ ${name} is malformed and is being repaired at read time.\n` +
      `  Stored: ${JSON.stringify(raw.length > 60 ? `${raw.slice(0, 60)}…` : raw)}\n` +
      "  Fix it in the hosting dashboard — the repair is a safety net, not a fix."
  );
}

const rawUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const rawKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const url = firstLine(rawUrl);
const key = firstLine(rawKey);

warnIfRepaired("NEXT_PUBLIC_SUPABASE_URL", rawUrl, url);
warnIfRepaired("NEXT_PUBLIC_SUPABASE_ANON_KEY", rawKey, key);

if (!url || !key) {
  // Not a failure. Forks cannot read repository secrets, and a fresh clone
  // has no .env yet — both build fine today, and this check exists to catch
  // wrong values, not to introduce a new way to fail.
  console.warn(
    "\n⚠ Supabase environment is not set, so it could not be checked." +
      "\n  The app will not reach Supabase at runtime. Expected on a fork.\n"
  );
  process.exit(0);
}

// The project this build points at, per the URL.
let host;
try {
  host = new URL(url).host;
} catch {
  fail(`NEXT_PUBLIC_SUPABASE_URL is not a URL (${JSON.stringify(url)}).`, "Expected https://<ref>.supabase.co.");
}
const urlRef = host.split(".")[0];

// The project the key is *for*, per its own payload.
const segments = key.split(".");
if (segments.length !== 3) {
  fail(
    "NEXT_PUBLIC_SUPABASE_ANON_KEY is not a JWT (expected three dot-separated parts, " +
      `got ${segments.length}).`,
    "A doubled paste looks like this. Copy the key once, with no trailing newline."
  );
}

let payload;
try {
  const base64 = segments[1].replace(/-/g, "+").replace(/_/g, "/");
  payload = JSON.parse(Buffer.from(base64, "base64").toString("utf8"));
} catch {
  fail("NEXT_PUBLIC_SUPABASE_ANON_KEY's payload could not be decoded.", "Re-copy it from Supabase.");
}

if (payload.ref !== urlRef) {
  fail(
    `the key belongs to project "${payload.ref}" but the URL points at "${urlRef}".`,
    "These must be the same project, or every request will be rejected."
  );
}

if (payload.role !== "anon") {
  fail(
    `NEXT_PUBLIC_SUPABASE_ANON_KEY has role "${payload.role}", not "anon".`,
    "Never ship a service-role key to the browser — it bypasses every RLS policy."
  );
}

if (typeof payload.exp === "number" && payload.exp * 1000 < Date.now()) {
  fail(
    `the anon key expired on ${new Date(payload.exp * 1000).toISOString().slice(0, 10)}.`,
    "Rotate it in Supabase → API keys and update the hosting environment."
  );
}

console.log(`✓ Supabase env OK — anon key matches project "${urlRef}".`);
