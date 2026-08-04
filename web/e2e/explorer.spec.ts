import { expect, test } from "@playwright/test";

test("visiting /explorer while signed out redirects to /login", async ({ page }) => {
  await page.goto("/explorer");
  await expect(page).toHaveURL(/\/login/);
});
