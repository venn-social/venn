import react from "@vitejs/plugin-react";
import path from "node:path";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    // Playwright owns e2e/ — its *.spec.ts files use @playwright/test's
    // own test()/expect(), which would otherwise collide with Vitest's
    // default *.spec.ts discovery.
    exclude: ["node_modules/**", "e2e/**"],
    // Any component that talks to Supabase now builds a client on mount —
    // the live notification badge does — and @supabase/ssr throws without
    // these. Dummy values: nothing in the unit suite makes a real request,
    // and a test that started to would fail loudly rather than quietly
    // reaching production.
    env: {
      NEXT_PUBLIC_SUPABASE_URL: "http://localhost:54321",
      NEXT_PUBLIC_SUPABASE_ANON_KEY: "test-anon-key",
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(import.meta.dirname, "."),
    },
  },
});
