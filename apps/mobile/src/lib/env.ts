/**
 * env.ts — validated access to environment variables.
 *
 * Why this exists:
 *   Expo exposes env vars via `process.env.EXPO_PUBLIC_*`, but those are typed
 *   as `string | undefined`. If you forget to set one, the app silently fails
 *   at runtime. This module validates up-front and crashes loudly with a clear
 *   message when a required variable is missing, so the problem is obvious.
 *
 * Usage:
 *   import { env } from '@/lib/env';
 *   const url = env.SUPABASE_URL; // typed as string, never undefined
 */

type AppEnvironment = 'development' | 'staging' | 'production';

interface Env {
  readonly SUPABASE_URL: string;
  readonly SUPABASE_ANON_KEY: string;
  readonly APP_ENV: AppEnvironment;
  /** Sentry DSN. When null, error tracking is disabled (local dev, missing config). */
  readonly SENTRY_DSN: string | null;
  /** PostHog API key. When null, analytics is disabled. */
  readonly POSTHOG_API_KEY: string | null;
  /** PostHog API host. Defaults to PostHog Cloud (US). */
  readonly POSTHOG_HOST: string;
}

function requireString(name: string, value: string | undefined): string {
  if (value === undefined || value === '') {
    throw new Error(
      `Missing required environment variable: ${name}. ` +
        `Check apps/mobile/.env (copy from .env.example if you haven't yet).`,
    );
  }
  return value;
}

function optionalString(value: string | undefined): string | null {
  return value !== undefined && value.length > 0 ? value : null;
}

function parseAppEnv(value: string | undefined): AppEnvironment {
  if (value === 'staging' || value === 'production') {
    return value;
  }
  return 'development';
}

export const env: Env = {
  SUPABASE_URL: requireString('EXPO_PUBLIC_SUPABASE_URL', process.env.EXPO_PUBLIC_SUPABASE_URL),
  SUPABASE_ANON_KEY: requireString(
    'EXPO_PUBLIC_SUPABASE_ANON_KEY',
    process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY,
  ),
  APP_ENV: parseAppEnv(process.env.EXPO_PUBLIC_APP_ENV),
  SENTRY_DSN: optionalString(process.env.EXPO_PUBLIC_SENTRY_DSN),
  POSTHOG_API_KEY: optionalString(process.env.EXPO_PUBLIC_POSTHOG_API_KEY),
  POSTHOG_HOST: process.env.EXPO_PUBLIC_POSTHOG_HOST ?? 'https://us.i.posthog.com',
};
