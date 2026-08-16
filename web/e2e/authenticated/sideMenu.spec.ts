import { expect, test } from "@playwright/test";
import { hasAdminCredentials } from "../support/testUser";

/**
 * The side menu, end to end.
 *
 * It is the *only* route to Settings, Lists, Activity and Last 12 Months —
 * the profile page stopped linking Settings, and the nav stopped listing
 * Lists and Activity. So if this control breaks, four screens become
 * unreachable and nothing else in the suite would notice: every page still
 * renders correctly when visited directly by URL.
 *
 * It has already broken once in a way tests could not see. SwiftUI merged
 * the equivalent iOS panel into a single accessibility element, so the rows
 * existed visually but not to VoiceOver or to a UI test. Same class of
 * failure, same invisibility.
 *
 * Follows the convention of the suite it sits beside: assertions stay on
 * structure the fixture guarantees, never on seeded content.
 */
test.describe("side menu", () => {
  test.skip(!hasAdminCredentials(), "Needs SUPABASE_SERVICE_ROLE_KEY.");

  test("holds exactly the four secondary surfaces, in order", async ({ page }) => {
    await page.goto("/feed");
    await page.getByRole("button", { name: /More/ }).click();

    const menu = page.locator("#side-menu");
    await expect(menu.getByRole("link")).toHaveText([
      "Settings",
      "Lists",
      "Activity",
      "Last 12 Months"
    ]);
  });

  test("each entry actually reaches its screen", async ({ page }) => {
    // The list rendering correctly says nothing about the hrefs being right.
    for (const [name, path] of [
      ["Settings", "/settings"],
      ["Lists", "/lists"],
      ["Activity", "/notifications"],
      ["Last 12 Months", "/profile/year"]
    ] as const) {
      await page.goto("/feed");
      await page.getByRole("button", { name: /More/ }).click();
      await page.locator("#side-menu").getByRole("link", { name }).click();

      await expect(page).toHaveURL(new RegExp(`${path}$`));
      await expect(page).not.toHaveURL(/\/login/);
    }
  });

  test("does not leave the panel open over the page you asked for", async ({ page }) => {
    // Every visit would otherwise start with a dismissal.
    await page.goto("/feed");
    await page.getByRole("button", { name: /More/ }).click();
    await page.locator("#side-menu").getByRole("link", { name: "Lists" }).click();

    await expect(page).toHaveURL(/\/lists$/);
    await expect(page.locator("#side-menu")).toHaveCount(0);
  });

  test("the top nav no longer offers Lists or Activity", async ({ page }) => {
    // Two routes to the same screen is the state this replaced; a stray link
    // reappearing would quietly undo the point of the menu.
    await page.goto("/feed");

    const nav = page.getByRole("navigation");
    await expect(nav.getByRole("link", { name: "Lists" })).toHaveCount(0);
    await expect(nav.getByRole("link", { name: "Activity" })).toHaveCount(0);
  });

  test("the profile page no longer links Settings or Last 12 Months", async ({ page }) => {
    // Same reasoning from the other side: the menu is meant to be the one way.
    await page.goto("/profile");

    await expect(page.getByRole("link", { name: "Settings" })).toHaveCount(0);
    await expect(page.getByRole("link", { name: "Last 12 Months" })).toHaveCount(0);
    // Edit profile stays — it belongs to the profile, not to the menu.
    await expect(page.getByRole("link", { name: "Edit profile" })).toBeVisible();
  });
});

/**
 * The search-language preference, which is only worth having if it persists.
 */
test.describe("search language", () => {
  test.skip(!hasAdminCredentials(), "Needs SUPABASE_SERVICE_ROLE_KEY.");

  test("offers the supported languages and keeps the choice", async ({ page }) => {
    await page.goto("/settings");

    const picker = page.getByLabel("Search language");
    await expect(picker).toBeVisible();

    const before = await picker.inputValue();
    const next = before === "fr" ? "es" : "fr";

    await picker.selectOption(next);
    // Reload rather than trusting the in-memory value: the point of the
    // control is the write, and an optimistic picker looks identical to one
    // that saved when you never leave the page.
    await page.reload();
    await expect(page.getByLabel("Search language")).toHaveValue(next);

    await page.getByLabel("Search language").selectOption(before);
  });

  test("says what it does and does not promise a translated app", async ({ page }) => {
    // media is one shared row per item, so this cannot restate titles other
    // people logged. The copy has to be honest about that or the setting
    // reads as broken.
    await page.goto("/settings");

    await expect(page.getByText(/Titles other people have already logged/i)).toBeVisible();
  });
});
