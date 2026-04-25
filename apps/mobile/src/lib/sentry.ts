/**
 * sentry.ts — error tracking via Sentry.
 *
 * What this gives you:
 *   - Crashes and unhandled errors in production are captured with stack
 *     traces and grouped by signature in the Sentry dashboard.
 *   - In development, errors still surface in the LogBox; Sentry capture is
 *     enabled but tagged with environment="development" so you can filter it
 *     out (or turn it off entirely by leaving EXPO_PUBLIC_SENTRY_DSN unset).
 *   - When `EXPO_PUBLIC_SENTRY_DSN` is unset, Sentry is a no-op. Useful when
 *     a teammate doesn't yet have credentials, or for very-early local work.
 *
 * Manual capture:
 *   import { Sentry } from '@/lib/sentry';
 *   try { ... } catch (e) { Sentry.captureException(e); throw e; }
 *
 * Tagging the user (do this once login succeeds):
 *   Sentry.setUser({ id: user.id, username: user.username });
 */
import * as Sentry from '@sentry/react-native';

import { env } from '@/lib/env';

let initialized = false;

export function initSentry(): void {
  if (initialized) {
    return;
  }
  initialized = true;

  if (env.SENTRY_DSN === null) {
    // No DSN configured. Leave Sentry uninitialized; calls become no-ops.
    return;
  }

  Sentry.init({
    dsn: env.SENTRY_DSN,
    environment: env.APP_ENV,
    enableAutoSessionTracking: true,
    debug: env.APP_ENV === 'development',
    // Keep traces light by default; turn this up when we actually look at perf.
    tracesSampleRate: env.APP_ENV === 'production' ? 0.1 : 0,
  });
}

export { Sentry };
