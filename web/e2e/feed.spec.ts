import { expect, test } from "@playwright/test";

// Signed-out coverage only: the suite still has no authenticated-session
// fixture (docs/TECH_DEBT.md row 13), so the feed's rendered content is
// covered by component tests instead of end to end.
test.describe("feed auth gate", () => {
  test("visiting /feed while signed out redirects to /login", async ({ page }) => {
    await page.goto("/feed");
    await expect(page).toHaveURL(/\/login/);
  });

  test("the nav is not shown on the sign-in page", async ({ page }) => {
    await page.goto("/login");
    await expect(page.getByRole("link", { name: "Feed" })).toHaveCount(0);
  });
});
