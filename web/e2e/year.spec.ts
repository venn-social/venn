import { expect, test } from "@playwright/test";

test("visiting /profile/year while signed out redirects to /login", async ({ page }) => {
  await page.goto("/profile/year");
  await expect(page).toHaveURL(/\/login/);
});
