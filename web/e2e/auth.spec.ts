import { expect, test } from "@playwright/test";

/**
 * Magic-link sign-in flow — mirrors the scope of iOS's
 * testAuthSubmitValidEmailShowsSentConfirmationThenResets /
 * testAuthSubmitRateLimitedEmailShowsError UI tests: verifies the UI reacts
 * correctly to a submit, not that a real email round-trip completes (that's
 * what iOS's own tests cover too — email delivery isn't retested per
 * platform).
 *
 * The Supabase OTP call is intercepted rather than hitting the real
 * project: sending real magic-link emails from an automated test would
 * burn the project's email rate limit (~3-4/hr), which is shared with
 * actual development use.
 */
test.describe("magic-link sign-in", () => {
  test("submitting a valid email shows the check-your-inbox confirmation", async ({ page }) => {
    await page.route("**/auth/v1/otp*", async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: "{}" });
    });

    await page.goto("/login");
    await expect(page.getByText("venn")).toBeVisible();

    await page.getByPlaceholder("Email").fill("charles@example.com");
    await page.getByRole("button", { name: "Continue" }).click();

    await expect(page.getByText("Check your inbox")).toBeVisible();
    await expect(page.getByText("charles@example.com")).toBeVisible();
  });

  test("shows an error message when the send fails", async ({ page }) => {
    await page.route("**/auth/v1/otp*", async (route) => {
      await route.fulfill({
        status: 429,
        contentType: "application/json",
        body: JSON.stringify({ error: "over_email_send_rate_limit" }),
      });
    });

    await page.goto("/login");
    await page.getByPlaceholder("Email").fill("charles@example.com");
    await page.getByRole("button", { name: "Continue" }).click();

    await expect(page.getByText("Couldn't send the magic link. Please try again.")).toBeVisible();
  });

  test("use a different email resets back to the form", async ({ page }) => {
    await page.route("**/auth/v1/otp*", async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: "{}" });
    });

    await page.goto("/login");
    await page.getByPlaceholder("Email").fill("charles@example.com");
    await page.getByRole("button", { name: "Continue" }).click();
    await expect(page.getByText("Check your inbox")).toBeVisible();

    await page.getByRole("button", { name: "Use a different email" }).click();
    await expect(page.getByPlaceholder("Email")).toBeVisible();
  });
});
