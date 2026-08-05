import { expect, test } from "@playwright/test";

// Signed-out coverage only — the suite still has no authenticated-session
// fixture (docs/TECH_DEBT.md row 13).
test.describe("social routes auth gate", () => {
  test("a post permalink redirects to /login when signed out", async ({ page }) => {
    await page.goto("/post/00000000-0000-0000-0000-000000000000");
    await expect(page).toHaveURL(/\/login/);
  });

  test("/lists redirects to /login when signed out", async ({ page }) => {
    await page.goto("/lists");
    await expect(page).toHaveURL(/\/login/);
  });

  test("a single list redirects to /login when signed out", async ({ page }) => {
    await page.goto("/lists/00000000-0000-0000-0000-000000000000");
    await expect(page).toHaveURL(/\/login/);
  });
});

test("a media detail page redirects to /login when signed out", async ({ page }) => {
  await page.goto("/media/00000000-0000-0000-0000-000000000000");
  await expect(page).toHaveURL(/\/login/);
});
