import { createClient, type SupabaseClient } from "@supabase/supabase-js";

/**
 * The dedicated end-to-end user.
 *
 * A fixed address rather than a random one per run: Supabase counts every
 * distinct signup against the project's user quota, and a run that dies
 * between creating a user and cleaning it up would leak one every time.
 * Reusing a single account means the worst case is a stale row, not an
 * unbounded pile of them.
 *
 * `@venn.test` is deliberately not a deliverable domain — nothing can be
 * emailed to it even by accident.
 */
export const TEST_USER = {
  email: "e2e@venn.test",
  username: "e2etester",
  displayName: "E2E Tester"
} as const;

/** Where the signed-in browser state is cached between projects. */
export const STORAGE_STATE = "e2e/.auth/state.json";

/**
 * True when CI (or a developer) has supplied the service-role key.
 *
 * Everything authenticated is gated on this. Without it the suite still
 * runs — it just covers the signed-out surface only, which is exactly what
 * a fork's pull request should get: forks can't read repository secrets,
 * and a suite that hard-fails there would make every outside contribution
 * look broken.
 */
export function hasAdminCredentials(): boolean {
  return Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY && process.env.NEXT_PUBLIC_SUPABASE_URL);
}

function adminClient(): SupabaseClient {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !serviceRoleKey) {
    throw new Error("SUPABASE_SERVICE_ROLE_KEY and NEXT_PUBLIC_SUPABASE_URL are required.");
  }

  // No session persistence: this client exists for the length of one setup
  // run and must never write its credentials anywhere the browser can read.
  return createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false }
  });
}

/**
 * Make sure the test user exists, is confirmed, and has finished
 * onboarding — then hand back a one-time code for signing them in.
 *
 * The profile row matters as much as the account: the onboarding gate in
 * `lib/supabase/proxy.ts` bounces any signed-in user without one straight
 * to `/onboarding`, so without it every authenticated test would assert
 * against the wrong page.
 */
export async function prepareTestUser(): Promise<string> {
  const admin = adminClient();
  const userId = await ensureUser(admin);
  await ensureProfile(admin, userId);
  return await mintOneTimeCode(admin);
}

async function ensureUser(admin: SupabaseClient): Promise<string> {
  const { data, error } = await admin.auth.admin.createUser({
    email: TEST_USER.email,
    email_confirm: true
  });

  if (data?.user) return data.user.id;

  // Already registered — the expected path on every run after the first.
  const existing = await findUserByEmail(admin);
  if (existing) return existing;

  throw new Error(`Could not create or find the E2E user: ${error?.message ?? "unknown error"}`);
}

async function findUserByEmail(admin: SupabaseClient): Promise<string | null> {
  // listUsers has no email filter, so page through until the address turns
  // up. The project has few enough users for this to stay cheap, and it
  // beats keeping the user id in a second secret.
  for (let page = 1; page <= 10; page += 1) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw error;

    const match = data.users.find((user) => user.email === TEST_USER.email);
    if (match) return match.id;
    if (data.users.length < 200) return null;
  }
  return null;
}

async function ensureProfile(admin: SupabaseClient, userId: string): Promise<void> {
  const { error } = await admin
    .from("profiles")
    .upsert(
      {
        id: userId,
        username: TEST_USER.username,
        display_name: TEST_USER.displayName,
        is_private: false
      },
      { onConflict: "id" }
    )
    .select()
    .single();

  if (error) throw new Error(`Could not upsert the E2E profile: ${error.message}`);
}

/**
 * A valid six-digit sign-in code, generated **without sending an email**.
 *
 * `generateLink` only mints the token; nothing is delivered. That matters:
 * the project's built-in sender throttles at three or four messages an
 * hour and that budget is shared with real development, so a test suite
 * that actually sent mail would lock the team out of their own app.
 */
async function mintOneTimeCode(admin: SupabaseClient): Promise<string> {
  const { data, error } = await admin.auth.admin.generateLink({
    type: "magiclink",
    email: TEST_USER.email
  });

  if (error) throw new Error(`Could not generate a sign-in code: ${error.message}`);

  const code = data.properties?.email_otp;
  if (!code) throw new Error("Supabase returned no email_otp for the generated link.");
  return code;
}
