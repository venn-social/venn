import { defineConfig, devices } from "@playwright/test";

/**
 * Two suites, not one.
 *
 * `chromium` runs signed out — the auth gate and the sign-in form, anything
 * a visitor can reach. `authenticated` runs against a real session minted
 * by the `setup` project, which is where the interesting behaviour lives:
 * RLS policies, the onboarding gate, and every page that only renders for a
 * signed-in user.
 *
 * The setup project needs `SUPABASE_SERVICE_ROLE_KEY`. Without it it writes
 * an empty cookie jar and the authenticated specs skip themselves, so a
 * fork's pull request still gets a green signed-out run rather than a wall
 * of failures it has no way to fix.
 */
export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  reporter: "list",
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
  },
  projects: [
    { name: "setup", testMatch: /.*\.setup\.ts/ },
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
      testIgnore: /authenticated\/.*/,
    },
    {
      name: "authenticated",
      testMatch: /authenticated\/.*\.spec\.ts/,
      use: { ...devices["Desktop Chrome"], storageState: "e2e/.auth/state.json" },
      dependencies: ["setup"],
    },
  ],
  webServer: {
    command: "npm run build && npm run start",
    url: "http://localhost:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
