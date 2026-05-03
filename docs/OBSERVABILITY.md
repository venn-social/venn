# Observability — Sentry + PostHog

Two tools, two purposes:

- **Sentry** — when something breaks, we want to know. Errors and crashes are captured with stack traces, grouped, and viewable in the Sentry dashboard.
- **PostHog** — what are people doing? Screen views, button taps, feature flags, funnels. Behavioral, not exception-based.

Both bootstrap from `Observability.bootstrap(config:)` in `ios/Venn/Services/Observability.swift`. Both no-op cleanly if their key/DSN is unset, so local development works with empty observability values in `.env`.

---

## Setup

In `.env` (read by the build script):

```env
SENTRY_DSN=https://<key>@<org>.ingest.sentry.io/<project>
POSTHOG_API_KEY=phc_xxx
POSTHOG_HOST=https://us.i.posthog.com
```

Both vars are optional. Leave them blank in dev and the SDKs won't initialize. Production builds always set them.

---

## Sentry — error reporting

### What gets captured automatically

- All uncaught Swift errors and runtime crashes.
- Network errors via `URLSession` (Sentry swizzles `URLProtocol`).
- App lifecycle events (foreground, background, low-memory warnings).
- Performance traces at `tracesSampleRate` (1.0 in dev, 0.2 in prod) and profiling at `profilesSampleRate` (1.0 in dev, 0.1 in prod).

### What to add manually

When you catch an error and want to keep it as breadcrumb context (vs. showing a user-facing alert):

```swift
import Sentry

do {
    try await service.fetchPosts()
} catch {
    SentrySDK.capture(error: error) { scope in
        scope.setTag(value: "feed", key: "feature")
        scope.setLevel(.warning)
    }
    self.error = AppError(error)
}
```

Tag with `feature: <name>` for every error so the Sentry dashboard groups by feature. Sentry's built-in grouping is by stack trace; tags are how _we_ slice the data.

### What NOT to do

- **Don't `SentrySDK.capture` and re-throw the same error.** Pick one — either the error stays internal (capture + handle) or it bubbles up (don't capture; the call site decides what to do).
- **Don't capture user-facing validation errors.** "Username too short" is not a Sentry event; it's a UI state.
- **Don't set user context to anything more than `user.id`.** No emails, no display names — those go to PostHog.

---

## PostHog — product analytics

### What gets captured automatically

- Screen views (via `captureScreenViews = true`).
- App lifecycle events (`captureApplicationLifecycleEvents = true`).
- Auto-captured user properties (device, OS, app version).

### Custom events

Naming convention: `feature.action_object` in `lower_snake_case`.

```swift
import PostHog

PostHogSDK.shared.capture("feed.refreshed", properties: [
    "post_count": viewModel.posts.count,
    "trigger": "pull_to_refresh"
])
```

| When                                     | Event name                |
| ---------------------------------------- | ------------------------- |
| User signs in successfully               | `auth.signed_in`          |
| User submits a post                      | `feed.post_created`       |
| User opens someone else's profile        | `profile.viewed_other`    |
| User taps the Venn-overlap visualization | `profile.overlap_tapped`  |
| User adds a movie to "Want to Try"       | `taste.want_to_try_added` |

Add a new event whenever you ship a feature where "did people use this?" is a question worth answering. Don't add events for trivial UI state ("settings_panel_opened" is rarely useful).

### Identifying users

```swift
import PostHog

PostHogSDK.shared.identify(user.id.uuidString, userProperties: [
    "handle": user.handle,
    "joined_at": user.createdAt.ISO8601Format()
])
```

Call this once at sign-in. Reset on sign-out:

```swift
PostHogSDK.shared.reset()
```

### What NOT to do

- **Don't capture every tap.** Auto-screen-view + manual capture for important actions is the right balance.
- **Don't put PII in event properties.** `user.id` is fine (UUIDs, not emails). No display names, no bios, no message content.
- **Don't gate features on PostHog feature flags without a fallback.** If PostHog is unreachable (network, rate-limited), the feature must still resolve to a sensible default.

---

## Local debugging

Sentry: pass `--launch-arguments=SENTRY_DEBUG=1` to a scheme to log every captured event. Useful when you're not sure if an error you handled actually made it to the dashboard.

PostHog: events show up in the **Live Events** view in the PostHog dashboard within a few seconds. The simulator's IP is what shows up in PostHog, so events from your laptop are easy to filter out (set a property `is_developer: true` and add a Sentry filter).

---

## Alerts

Sentry alerts (configured in the Sentry dashboard, not code):

- New unique error → Slack `#engineering`
- Error rate > 5/min sustained → Slack `#engineering` + email founder

PostHog alerts:

- Daily active users drops > 30% week-over-week → email founder
- Funnel drop-off > 20% step-over-step → Slack `#engineering`

We'll tighten these as the user base grows. For now they're noise-tolerant defaults.
