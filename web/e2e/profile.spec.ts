import { expect, test } from "@playwright/test";

/**
 * `/[username]` and `/requests` both require a signed-in session (see
 * app/[username]/page.tsx and app/requests/page.tsx) — real interactive
 * sign-in isn't automatable here (magic-link auth, no test-user fixture
 * exists yet), so this suite covers the one thing that's genuinely real
 * and testable without one: the auth gate itself. FollowButton's
 * click behavior is covered instead by
 * components/__tests__/FollowButton.test.tsx (Vitest + RTL, mocks
 * lib/follow directly — no server or session needed).
 */
test.describe("auth gate", () => {
  test("visiting a public profile while signed out redirects to /login", async ({ page }) => {
    await page.goto("/venn");
    await expect(page).toHaveURL("/login");
  });

  test("visiting a nonexistent username while signed out redirects to /login", async ({ page }) => {
    await page.goto("/this-username-should-not-exist-anywhere-12345");
    await expect(page).toHaveURL("/login");
  });

  test("visiting /requests while signed out redirects to /login", async ({ page }) => {
    await page.goto("/requests");
    await expect(page).toHaveURL("/login");
  });
});
