# 0007 — Sentry for errors, PostHog for product analytics

- **Status:** Proposed
- **Date:** 2026-05-08
- **Deciders:** Charles Salomon

## Context

A consumer iOS app needs two distinct telemetry streams:

1. **Crash + error reporting.** When the app crashes or hits an unexpected error path on a real user's device, we need a stack trace, the breadcrumbs leading up to it, the device + OS version, and the build that produced it. Without this, every "the app froze" report is a mystery.
2. **Product analytics.** When a user opens the app, signs up, posts an item, or churns, we need event-level data we can slice by cohort, time, and feature. Without this, every product decision is opinion.

These are different shapes of data with different ingestion tools, different sampling strategies, and different stakeholders. Conflating them into one tool always disappoints both audiences.

The codebase already has both wired up (`ios/Venn/Services/Observability.swift` calls `SentrySDK.start(...)` and `PostHogSDK.shared.setup(...)`). Both SDKs are no-ops when their key/DSN is unset, so local dev is unaffected. This ADR documents the choice, not introduces it.

## Decision

Use **Sentry for errors and crashes**, **PostHog for product analytics**. Two separate vendors, one for each job.

- **Sentry** captures: crashes (signal handlers + uncaught exceptions), thrown errors that bubble to the UI layer (mapped via `Observability.captureError(_:)` to land in Sentry with breadcrumbs), and performance traces sampled at 20% in production / 100% in dev/staging. The DSN is optional in `.env`; absent DSN means Sentry no-ops.
- **PostHog** captures: lifecycle events (app open/background, screen views — auto-captured), explicit product events (`profile_edited`, `post_created`, `follow_added`, etc.) emitted by view-models on success, and cohort properties at sign-in (user ID, signup date, account age). The API key is optional; absent key means PostHog no-ops.
- **No PII to either.** User IDs are pseudonymous (the Supabase UUID), not emails or display names. We don't send post bodies, captions, search queries, or any user-typed content.
- **Bootstrap once.** `Observability.bootstrap(config:)` runs in `VennApp.init` before any view appears. There is no other place SDKs are initialised.
- **Wrappers, not raw SDK calls.** Feature code calls thin wrappers (`Observability.captureError`, `Analytics.track(_:)`) that internally delegate to Sentry / PostHog. This isolates the SDK surface — swapping a vendor later means rewriting the wrapper, not the call sites.

## Consequences

- **Easier:** error triage is one dashboard with stack traces grouped by hash. Product questions ("what fraction of users who edit their bio also add an avatar?") are one funnel query in PostHog. Both have free tiers that fit our scale through TestFlight and well past launch.
- **Harder:** two vendors means two billing relationships, two outage exposures, two SDKs to keep up to date in `Package.resolved`. Two privacy policies to consider when GDPR / app-tracking transparency conversations come up.
- **Committed to:** the wrapper pattern. Features must call `Observability.captureError` / `Analytics.track`, never the raw SDKs. Reversible — both wrappers are small.
- **Source map / dSYM upload:** to be wired into CI as a pre-release step before the first TestFlight build (deferred to ADR-when-it-matters; tracked in session notes).

## Alternatives considered

- **Sentry only (use Sentry's session replay + custom events for analytics).** Sentry's analytics surface is shallow compared to PostHog. Funnels, retention curves, cohort analysis are not its strength.
- **PostHog only (use PostHog's exception capture for errors).** PostHog's exception capture works but doesn't compete with Sentry on iOS — symbolication, Apple-specific crash handling, dSYM workflow. Errors deserve a tool that takes them seriously.
- **Firebase Crashlytics + Mixpanel.** Crashlytics is fine but ties us to Firebase tooling we otherwise don't use (build a parallel auth account, etc.). Mixpanel is solid but more expensive than PostHog at our scale and has worse SQL access.
- **Datadog RUM.** Single tool, both jobs, enterprise-grade. Pricing model is hostile to a pre-revenue startup; we'd burn the runway on observability bills before launch.
- **Self-hosted PostHog + self-hosted Sentry.** Cost-effective at scale, operationally heavy at our size. Runs against the "we don't run infrastructure" principle in ADR 0003.
