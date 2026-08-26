import { expect, test } from "@playwright/test";
import { hasAdminCredentials, TEST_USER } from "../support/testUser";

/**
 * The signed-in surface, end to end against a real session.
 *
 * Until this existed the E2E suite could only prove that a signed-out
 * visitor gets redirected — every authenticated behaviour was covered
 * indirectly by component tests with a mocked Supabase client, which can't
 * catch an RLS policy that denies the read or a route that renders before
 * its data arrives.
 *
 * These assertions deliberately stay on structure the fixture guarantees
 * (the user's own profile, the nav, the auth gate) rather than on seeded
 * content: a shared project's rows come and go, and a test that depends on
 * them fails for reasons that have nothing to do with the code.
 */
test.describe("signed in", () => {
  test.skip(!hasAdminCredentials(), "Needs SUPABASE_SERVICE_ROLE_KEY.");

  test("lands on the profile rather than the sign-in page", async ({ page }) => {
    await page.goto("/profile");

    await expect(page).not.toHaveURL(/\/login/);
    await expect(page.getByText(`@${TEST_USER.username}`)).toBeVisible();
  });

  test("shows the persistent nav on signed-in pages", async ({ page }) => {
    await page.goto("/feed");

    await expect(page.getByRole("link", { name: "Feed" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Explorer" })).toBeVisible();
    await expect(page.getByRole("link", { name: "Profile" })).toBeVisible();
  });

  test("does not bounce a signed-in user back to onboarding", async ({ page }) => {
    // The gate in lib/supabase/proxy.ts redirects anyone without a profile
    // row. The fixture creates one, so reaching /feed proves the gate reads
    // it correctly — the bug it would catch is an onboarding loop.
    await page.goto("/feed");

    await expect(page).not.toHaveURL(/\/onboarding/);
  });

  test("the feed renders either posts or its empty state, never an error", async ({ page }) => {
    // Which one depends on who the test user follows, and that changes.
    // What must never appear is the failure copy — that's the symptom the
    // PGRST201 foreign-key regression produced on both platforms.
    await page.goto("/feed");

    await expect(page.getByText("Couldn't load the feed.")).toHaveCount(0);
    await expect(page.getByText("Quiet for now").or(page.locator("article").first())).toBeVisible();
  });

  test("explorer search reaches the catalog APIs", async ({ page }) => {
    await page.goto("/explorer");
    await page.getByPlaceholder("Search for anything").fill("past lives");

    // The search endpoint requires a session; signed out it 401s. Getting
    // past "Searching…" to a settled state is the assertion.
    await expect(page.getByText("Searching…")).toHaveCount(0, { timeout: 15_000 });
    await expect(page.getByText("Search failed.")).toHaveCount(0);
  });

  test("the auth gate refuses a protected route once the session is gone", async ({ page }) => {
    // Each test gets its own context seeded from the saved state, so
    // clearing cookies here can't leak into another spec.
    await page.context().clearCookies();
    await page.goto("/feed");

    await expect(page).toHaveURL(/\/login/);
  });

  test("explorer renders even when recommendations are thin", async ({ page }) => {
    // The E2E user has almost no history, so the interesting assertion is
    // not that shelves appear — it is that a nearly-empty recommendation
    // payload leaves Explorer working rather than blanking it.
    await page.goto("/explorer");

    await expect(page.getByPlaceholder("Search for anything")).toBeVisible();
    await expect(page.getByText("Couldn't load")).toHaveCount(0);
  });

  test("lists are reachable and render their own page", async ({ page }) => {
    await page.goto("/lists");

    await expect(page).not.toHaveURL(/\/login/);
    await expect(page.getByRole("heading", { name: "Lists" })).toBeVisible();
  });
});
