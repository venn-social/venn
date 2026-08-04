import { expect, test } from "@playwright/test";

test("visiting /composer while signed out redirects to /login", async ({ page }) => {
  await page.goto("/composer");
  await expect(page).toHaveURL(/\/login/);
});
