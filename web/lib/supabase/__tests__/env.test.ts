import { afterEach, describe, expect, it, vi } from "vitest";
import { supabaseAnonKey, supabaseUrl } from "@/lib/supabase/env";

/**
 * The outage this file exists to prevent.
 *
 * Production held the anon key twice, separated by a newline. `fetch`
 * refuses a header value containing a newline, so every sign-in threw
 * before a request was made — and Supabase's logs were empty, which made
 * the backend look innocent because it was.
 */

const KEY = "eyJhbGciOiJIUzI1NiJ9.eyJyb2xlIjoiYW5vbiJ9.signature";
const URL = "https://project.supabase.co";

afterEach(() => {
  vi.unstubAllEnvs();
});

describe("supabaseAnonKey", () => {
  it("survives the key being pasted twice", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", `${KEY}\n${KEY}`);
    expect(supabaseAnonKey()).toBe(KEY);
  });

  it("survives a trailing newline, the commonest bad paste", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", `${KEY}\n`);
    expect(supabaseAnonKey()).toBe(KEY);
  });

  it("survives leading blank lines and surrounding whitespace", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", `\n  ${KEY}  `);
    expect(supabaseAnonKey()).toBe(KEY);
  });

  it("strips quotes someone copied along with the value", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", `"${KEY}"`);
    expect(supabaseAnonKey()).toBe(KEY);
  });

  it("never returns a value that fetch would reject as a header", () => {
    // The actual property that matters: whatever comes back must be usable
    // in an Authorization header.
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", `${KEY}\r\n${KEY}\n`);
    expect(() => new Headers({ Authorization: `Bearer ${supabaseAnonKey()}` })).not.toThrow();
  });

  it("says which variable is wrong rather than failing obscurely", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "");
    expect(() => supabaseAnonKey()).toThrow(/NEXT_PUBLIC_SUPABASE_ANON_KEY/);
  });
});

describe("supabaseUrl", () => {
  it("cleans the URL the same way", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", `${URL}\n`);
    expect(supabaseUrl()).toBe(URL);
  });

  it("leaves a correct value untouched", () => {
    vi.stubEnv("NEXT_PUBLIC_SUPABASE_URL", URL);
    expect(supabaseUrl()).toBe(URL);
  });
});
