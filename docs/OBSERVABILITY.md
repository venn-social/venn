# Observability — Sentry + PostHog

Two tools, two purposes:

- **Sentry** — when something breaks, we want to know. Errors and crashes are captured with stack traces, grouped, and viewable in the Sentry dashboard.
- **PostHog** — when users do something, we want to know what. Product analytics events flow into PostHog so we can answer "is anyone actually clicking that button?" and "how many people get past sign-up?".

Both have generous free tiers. Both are wired up to be no-ops when not configured, so you can ship features without their keys and add the keys later.

---

## One-time setup (per environment)

You only need to do this once for the whole team — these are shared accounts.

### 1. Sentry

1. Go to [sentry.io/signup/](https://sentry.io/signup/) and create an organisation called `venn`.
2. Create a project: **Platform = React Native**, name = `venn-mobile`.
3. Copy the DSN. Format: `https://<key>@<org>.ingest.sentry.io/<project>`.
4. Paste it as `EXPO_PUBLIC_SENTRY_DSN` in your `apps/mobile/.env`.

### 2. PostHog

1. Go to [posthog.com/signup](https://posthog.com/signup) and create a `venn` workspace. Pick the **US** or **EU** region.
2. Project Settings → Project API Key. Format: `phc_<long-string>`.
3. Paste it as `EXPO_PUBLIC_POSTHOG_API_KEY` in your `apps/mobile/.env`.
4. Set `EXPO_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com` (default) or `https://eu.i.posthog.com` if you chose EU.

### 3. Verify

```bash
npm run mobile
```

The app should start as before. Trigger an error (e.g. throw something in a screen temporarily) and check the Sentry dashboard within a minute. Track an event with `trackEvent('test_event')` from any screen and check PostHog → Live events.

---

## How to use

### Capturing errors

Most errors get captured automatically via the `Sentry.wrap(RootLayout)` boundary in [`apps/mobile/src/app/_layout.tsx`](../apps/mobile/src/app/_layout.tsx). For caught errors you want to attribute, use:

```ts
import { Sentry } from '@/lib/sentry';

try {
  await riskyOperation();
} catch (error) {
  Sentry.captureException(error);
  throw error; // re-throw if you want it to fail loudly
}
```

When the user signs in, tag the session so errors are attributable:

```ts
Sentry.setUser({ id: user.id, username: profile.username });
```

When they sign out, clear it:

```ts
Sentry.setUser(null);
```

### Tracking events

Use the helpers from `@/lib/analytics`. Don't import `posthog-react-native` directly elsewhere — keep it wrapped so the dev-mode no-op behavior holds.

```ts
import { trackEvent, identifyUser, resetAnalytics } from '@/lib/analytics';

// On sign-in:
identifyUser(user.id, { username: profile.username, joinedAt: profile.created_at });

// On meaningful actions:
trackEvent('post_liked', { postId, vertical: 'movie' });
trackEvent('feed_refreshed', { previousPostCount: 24 });

// On sign-out:
resetAnalytics();
```

### Naming conventions (PostHog events)

- Event names are **snake_case verbs in past tense**: `post_liked`, `profile_viewed`, `feed_refreshed`. Past tense because we're recording things that happened.
- Property keys are **camelCase**.
- Don't put PII beyond user id + username. No emails, no full names, no birthdays. (User id and username are pseudonymous in our context.)
- Don't track every render or navigation by hand — PostHog has auto-capture for screens via `<PostHogProvider>` if we want it later.

---

## Local dev: do you turn it on?

**Default: no.** Leave both env vars empty in your `apps/mobile/.env`. The app behaves identically; the SDKs are no-ops. Your local error-throwing experiments don't pollute the team's Sentry dashboard.

**When to turn it on locally:** debugging integration issues with the SDKs themselves, or testing a flow you want to verify lands in PostHog before shipping. Use a dedicated personal dev Sentry project if you go this route.

---

## Production

When we set up CI/EAS Build (item 4 of the audit), the same env vars will need to be set as GitHub Actions secrets and as EAS build secrets. We'll add that step then.

For now, the production app gets the values from `.env` at build time — same as local, just with real keys.

---

## What's intentionally not set up yet

These are reasonable to add later when there's a clear use case:

- **Sentry source maps.** Stack traces in production currently point at minified bundle line numbers. Add the Sentry CLI to EAS Build to upload source maps when we set up real builds.
- **Sentry release tracking.** Tagging crashes with the app version helps spot regressions. Set this once we have versioning + EAS build numbers.
- **PostHog feature flags.** PostHog can ship feature flags. Useful when we want to gate new features. Out of scope until we have features to gate.
- **PostHog auto-capture.** Off by default. Turn on `<PostHogProvider autocapture={...}>` if you want screen views recorded automatically.
- **Sentry session replay.** Records what users do on the screen. Powerful, privacy-loaded — opt-in only after we have a real privacy policy.
