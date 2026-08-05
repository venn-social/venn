import { mkdir, writeFile } from "node:fs/promises";
import { dirname } from "node:path";
import { expect, test as setup } from "@playwright/test";
import { hasAdminCredentials, prepareTestUser, STORAGE_STATE, TEST_USER } from "./support/testUser";

/**
 * Signs in once and saves the cookie jar for every authenticated spec.
 *
 * The session is minted through the app's own sign-in form rather than by
 * hand-writing auth cookies. Cookie names, chunking, and encoding are
 * `@supabase/ssr` implementation details that change between releases;
 * driving the real form means the state is correct by construction, and it
 * doubles as coverage of the code-entry path.
 *
 * No email is ever sent. The code comes from the admin API, and the send
 * request the form makes is intercepted — see `support/testUser.ts` on why
 * that budget is too small to spend on tests.
 */
setup("authenticate", async ({ page }) => {
  if (!hasAdminCredentials()) {
    // Forks and local runs without the key: leave an empty jar so the
    // authenticated project still loads, and let its specs skip themselves.
    await writeEmptyState();
    setup.skip(true, "SUPABASE_SERVICE_ROLE_KEY is not set — skipping authenticated tests.");
    return;
  }

  const code = await prepareTestUser();

  await page.route("**/auth/v1/otp*", async (route) => {
    await route.fulfill({ status: 200, contentType: "application/json", body: "{}" });
  });

  await page.goto("/login");
  await page.getByPlaceholder("Email").fill(TEST_USER.email);
  await page.getByRole("button", { name: "Continue" }).click();

  await expect(page.getByText("Check your inbox")).toBeVisible();
  await page.getByPlaceholder("Code from email").fill(code);
  await page.getByRole("button", { name: "Verify code" }).click();

  // The gate redirects a signed-in user with a profile away from /login.
  // Waiting on that, rather than on a fixed URL, keeps this working if the
  // post-sign-in landing page ever moves.
  await expect(page).not.toHaveURL(/\/login/);
  await page.context().storageState({ path: STORAGE_STATE });
});

async function writeEmptyState(): Promise<void> {
  await mkdir(dirname(STORAGE_STATE), { recursive: true });
  await writeFile(STORAGE_STATE, JSON.stringify({ cookies: [], origins: [] }), "utf8");
}
