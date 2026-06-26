# 0009 — Distribute to TestFlight with Fastlane on GitHub Actions

- **Status:** Accepted
- **Date:** 2026-06-26
- **Deciders:** Charles (`@cslmn`)

## Context

The app builds and tests on the simulator in CI, but there's no path to a signed build on a real device or in TestFlight — the December 2026 TestFlight target needs one. The hard prerequisite is an **Apple Developer Program** account ($99/yr); nothing can sign or upload without it, and none of the pipeline can be verified until it's active.

Given the account, we need to choose how builds get archived, signed, and uploaded. The team is small and non-technical but treats this as a professional engineering project, and already runs CI on **GitHub Actions** (`macos-latest`). We want the release path to live next to the code, be reproducible, and not depend on a single person's Mac or Xcode GUI.

## Decision

Distribute to TestFlight with **Fastlane, driven from GitHub Actions**. A `fastlane/Fastfile` defines a `beta` lane that signs with **Fastlane Match** (certificates + provisioning profiles stored encrypted in a private git repo), archives via `build_app`, and uploads with `upload_to_testflight`. A dedicated workflow (`.github/workflows/testflight.yml`), triggered on a `v*` tag or manual `workflow_dispatch`, runs that lane using an **App Store Connect API key** (not a personal Apple ID) held in GitHub Actions secrets. The simulator CI in `ci.yml` is unchanged; release is its own workflow.

The pipeline is **built and verified once the Apple Developer account is active** — signing config (team ID, cert types, profile names, export method) can only be debugged against the real account, so writing it blind first would be rework. Until then, [`docs/RELEASE.md`](../RELEASE.md) holds the account-setup checklist so the human prerequisites can start immediately.

## Consequences

- **Easier:** any maintainer can cut a TestFlight build by pushing a tag — no one's local Xcode or Apple ID is in the loop. Signing assets are versioned and shared via Match. The release path is reproducible and reviewable like any other code.
- **Harder:** more moving parts than Xcode Cloud — a private certs repo, an ASC API key, a Match passphrase, and ~5 GitHub secrets to manage. The first green build will take a few debugging iterations against the real account (signing is fiddly). Fastlane is a Ruby toolchain to keep updated.
- **Committed to:** Apple Developer Program enrollment; an App Store Connect API key for CI; a private `certificates` repo for Match; bundle ID `social.venn.app`. Reversible to Xcode Cloud later, but that's a separate setup.

## Alternatives considered

- **Manual Xcode Archive → Distribute.** Fastest to a first build and zero infra, but not reproducible, ties releases to one person's machine, and doesn't scale to per-PR/dogfood builds. Fine as a one-off fallback, not as the pipeline.
- **Xcode Cloud.** Apple-native, easiest signing (Apple manages certs), minimal scripting — but it's configured in the App Store Connect GUI (not in-repo), runs parallel to our GitHub Actions rather than with it, and has compute-hour cost tiers. Chose Fastlane to keep the release path in version control alongside the existing CI.
