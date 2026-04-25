/**
 * analytics.ts — product analytics via PostHog.
 *
 * What you get:
 *   - A singleton PostHog client used by feature code via the helpers below.
 *   - When `EXPO_PUBLIC_POSTHOG_API_KEY` is unset, every call is a no-op. That
 *     keeps local dev quiet and prevents accidental dev-data pollution of
 *     production analytics.
 *
 * Usage:
 *   import { trackEvent, identifyUser, resetAnalytics } from '@/lib/analytics';
 *   trackEvent('post_liked', { postId, vertical: 'movie' });
 *   identifyUser(user.id, { username, joinedAt });
 *   resetAnalytics(); // call on sign-out
 *
 * Conventions:
 *   - Event names are snake_case verbs ("post_liked", "feed_refreshed").
 *   - Property keys are camelCase.
 *   - Don't track PII beyond user id + username. No emails, no full names.
 */
import { PostHog } from 'posthog-react-native';

import { env } from '@/lib/env';

type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { readonly [key: string]: JsonValue };

type EventProperties = Record<string, JsonValue>;

let client: PostHog | null = null;

/**
 * Returns the singleton PostHog client, or null if analytics is disabled
 * (POSTHOG_API_KEY unset). Wrap your provider tree with
 * `<PostHogProvider client={getPostHogClient() ?? undefined}>` or use the
 * `MaybePostHogProvider` pattern in `app/_layout.tsx`.
 */
export function getPostHogClient(): PostHog | null {
  if (client !== null) {
    return client;
  }
  if (env.POSTHOG_API_KEY === null) {
    return null;
  }
  client = new PostHog(env.POSTHOG_API_KEY, {
    host: env.POSTHOG_HOST,
  });
  return client;
}

export function trackEvent(event: string, properties?: EventProperties): void {
  const c = getPostHogClient();
  if (c === null) {
    return;
  }
  c.capture(event, properties);
}

export function identifyUser(userId: string, properties?: EventProperties): void {
  const c = getPostHogClient();
  if (c === null) {
    return;
  }
  c.identify(userId, properties);
}

export function resetAnalytics(): void {
  const c = getPostHogClient();
  if (c === null) {
    return;
  }
  c.reset();
}

/** True if analytics is configured (i.e. POSTHOG_API_KEY is set). */
export function isAnalyticsEnabled(): boolean {
  return getPostHogClient() !== null;
}
