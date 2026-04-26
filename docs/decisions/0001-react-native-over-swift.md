# 0001 — Build venn on React Native + Expo, not native Swift

- **Status:** Accepted
- **Date:** 2026-04-26
- **Deciders:** Charles Salomon

## Context

Charles asked how hard it would be to switch from React Native to native Swift early in the build (April 2026, before any real product code has shipped — the codebase at this point is auth scaffolding, sanitize utilities, env handling, and tooling). Swift gets you a more native-feeling iOS app and zero-cost access to iOS 26 system features (Liquid Glass material, SF Symbols, native navigation physics, the full Apple ecosystem). The cost is losing Android entirely, narrowing the hiring pool to iOS specialists, and replacing the Expo Go scan-the-QR workflow that lets non-technical co-founders run the app on their phones with an Xcode + USB + TestFlight loop.

The founding team is four people, three of them non-technical (Vivian, Teddy, Adam) and the founder (Charles) is non-engineer himself. The constraint that they can dogfood the app on their own phones — without owning Xcode, without plugging in a USB cable, without waiting 20 minutes for a TestFlight build — is load-bearing for the next 8 months.

## Decision

Build on React Native + Expo SDK 52 with the new architecture enabled. iOS-only at launch (December 2026 TestFlight target). The codebase remains cross-platform; Android publishing is deferred, not removed.

## Consequences

- **Easier:** Vivian, Teddy, Adam can scan a QR code from Expo Go and see the latest commit on their phones in seconds. The hiring pool is broader (React/RN developers vs. iOS specialists). The Supabase client, Sentry, PostHog, react-hook-form, zustand, and our entire utility stack work as one codebase.
- **Harder:** iOS 26's Liquid Glass material is not exposed to React Native natively; we either build a ~90% facsimile via `expo-blur` + careful styling, wait for a community bridge (likely mid–late 2026), or write a small native Swift module ourselves (1–2 days of work for someone we don't yet have on the team). Other native iOS feels — haptics, native nav, SF Symbols, spring animations — are already accessible via existing Expo packages.
- **Committed to:** TypeScript + React Native 0.76 + Expo SDK 52 + Expo Router + the existing observability/sanitize/rateLimit utility stack documented in [`CLAUDE.md`](../../CLAUDE.md). Reversing this decision later costs roughly a full rewrite — currently 1–2 weeks (the codebase is small) but growing every week.

## Alternatives considered

- **Swift + SwiftUI 7 (iOS 26).** Best native feel, free Liquid Glass, free SF Symbols, free everything Apple. But loses Android forever, locks the team into iOS specialists, and breaks the Expo Go scan-to-test workflow that lets non-technical co-founders dogfood the app daily. Defensible only if the app's UI quality bar is "indistinguishable from a Lovable / Beli / Insta-grade native iOS app" — which is a real concern but addressable in RN with effort.
- **Flutter.** Cross-platform like RN but smaller ecosystem (no Supabase RN-quality client, weaker Sentry SDK, fewer hires available). Dart is a language we'd add. RN won on familiarity for any web-leaning engineer who joins.
- **Capacitor / Ionic.** Web-in-a-shell. Performance and native feel are objectively worse than RN. Not seriously considered.
