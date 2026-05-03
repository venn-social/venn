# 0002 — Migrate from React Native + Expo to native Swift + SwiftUI

- **Status:** Accepted
- **Date:** 2026-05-01
- **Deciders:** Charles Salomon
- **Supersedes:** [0001 — Build venn on React Native + Expo, not native Swift](./0001-react-native-over-swift.md)

## Context

ADR 0001 (April 2026) chose React Native + Expo SDK 52, primarily to keep the team's "Expo Go scan-the-QR" feedback loop fast for non-technical co-founders, and to keep Android optionality alive.

Two weeks later, the calculus changed. The product's identity hinges on visual quality — overlap diagrams, profile cards, taste cards — and iOS 26's **Liquid Glass** material is the centerpiece of the look the founder wants to ship. The community React Native bridge for Liquid Glass has not materialized, and writing a custom native module to reach into iOS 26 system materials defeats the original "stay in JS land" point of choosing RN.

A second pressure point: the team is iOS-only at launch (December 2026 TestFlight). There is no concrete near-term plan to ship Android, and "we'll add Android later" is a 6+ month effort regardless of the framework. Holding open the Android option through Phase 1 was costing Liquid Glass, native nav physics, native haptics fidelity, full SF Symbols access, and a build size 3–5× larger than a native iOS app — for an option the team is unlikely to exercise before 2027 anyway.

The codebase at the time of this decision was ~2 weeks old. No real product features had shipped — the RN app contained auth scaffolding, sanitize utilities, env handling, and tooling. The migration cost is real but small relative to where the codebase will be in three months.

## Decision

Migrate to **native Swift 6 + SwiftUI on iOS 26+**. iOS only, no Android. The pre-migration codebase is preserved on the `archive/rn-expo` branch. The `main` branch is the new Swift codebase from this point on.

Specifically:

- **Language:** Swift 6 with `SWIFT_STRICT_CONCURRENCY=complete`.
- **UI:** SwiftUI on iOS 26 (minimum deployment target locked at 26.0).
- **Backend:** Unchanged — Supabase via [`supabase-swift`](https://github.com/supabase/supabase-swift). The Postgres schema, migrations, RLS, and Edge Functions are all platform-agnostic.
- **Project generation:** [XcodeGen](https://github.com/yonaskolb/XcodeGen). The `.xcodeproj` is generated from `ios/project.yml` and gitignored.
- **Dependencies:** Swift Package Manager only. No CocoaPods, no Carthage.
- **Tooling:** SwiftLint + SwiftFormat replace ESLint + Prettier-for-Swift. Husky + commitlint + Prettier-for-docs survive (language-agnostic).
- **CI:** GitHub Actions on `macos-latest` runners with current Xcode preinstalled.

## Consequences

- **Gained:** Liquid Glass, native navigation physics, full SF Symbols, native haptics fidelity, smaller binary, faster cold start, first-class access to every iOS 26 API as Apple ships them. Code that "feels native" without porting layers.
- **Lost:** Android. The "scan QR with Expo Go" feedback loop for non-technical co-founders — replaced with TestFlight (still fast: a build can be in their hands in ~10 minutes). The cross-platform option for ~6+ months of work later if Android ever becomes a priority.
- **Cost paid:** The pre-migration codebase (~2 weeks, no shipped features). The team's RN/TS muscle memory becomes irrelevant; everyone on the project needs to learn Swift + SwiftUI.
- **iOS 26 floor:** This excludes ~70% of the active iOS install base on day one (those still on iOS ≤ 25). Acceptable because (a) TestFlight launches in December 2026, by which point iOS 26 adoption will be ~50–60%, and (b) the target audience is younger, more likely to upgrade.

## Alternatives considered

- **Stay on RN, write a native module for Liquid Glass.** Solves only Liquid Glass; doesn't address the broader "every iOS API is a bridge away" friction. Builds a custom native maintenance burden anyway.
- **RN + SwiftUI bridge experiments.** Theoretically possible (e.g. via `react-native-skia` or hand-rolled native views) but the engineering effort is in the same ballpark as just going native, with worse outcomes.
- **Flutter.** Same Liquid Glass problem (no native bridge). Dart adoption cost. Not seriously reconsidered.
- **KMM (Kotlin Multiplatform).** Shares only logic; UI is still platform-specific. Solves a problem we don't have (we're iOS-only).
