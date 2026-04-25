# Dependencies — known vulns and why we're not patching them yet

Adding new dependencies needs a clear reason (per [`CLAUDE.md`](../CLAUDE.md) "Things NOT to do without asking"). This doc covers the inverse problem: what to do about known CVEs in dependencies we already have.

## TL;DR

GitHub Dependabot reports ~20 vulnerabilities on this repo. Every single one is in **transitive dev/build-time dependencies** pulled in by Expo's CLI tooling — none of them ships to user devices. The "fix" `npm audit fix --force` would downgrade Expo from SDK 52 to SDK 49, which is a non-starter. The right path is to wait for Expo's team to bump these in future SDK patches, monitor via Dependabot, and not panic in the meantime.

## What's actually there

As of 2026-04-25:

| Vulnerable package                                                                                                                                                                                           | Severity         | Pulled in by                                     | What it does                                                   |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------- | ------------------------------------------------ | -------------------------------------------------------------- |
| `uuid` (v3, v5, v6)                                                                                                                                                                                          | moderate         | `xcode`, `@expo/bunyan`, `@expo/rudder-sdk-node` | UUID generation in build-time tools                            |
| `@xmldom/xmldom` (<0.9)                                                                                                                                                                                      | high             | `@expo/plist`, `@expo/config-plugins`            | XML parsing for iOS plist files at build time                  |
| `postcss` (<8.5.4)                                                                                                                                                                                           | moderate         | `@expo/metro-config`                             | CSS processing in the Metro bundler                            |
| `tar`                                                                                                                                                                                                        | high             | npm install internals                            | npm's archive handling                                         |
| `cacache`                                                                                                                                                                                                    | high             | npm install internals                            | npm's package cache                                            |
| `jsdom`, `http-proxy-agent`, `@tootallnate/once`                                                                                                                                                             | low              | `jest-environment-jsdom`                         | Jest test runner                                               |
| `expo`, `expo-asset`, `expo-constants`, `expo-linking`, `expo-splash-screen`, `jest-expo`, `@expo/cli`, `@expo/config`, `@expo/config-plugins`, `@expo/metro-config`, `@expo/plist`, `@expo/prebuild-config` | high (cascading) | direct or near-direct on the above               | Expo's framework, all flagged because they depend on the above |

## Why we can't just `npm audit fix --force`

The fix the npm CLI proposes would install `expo@49.0.23` — that's two major SDK versions backward. We're on Expo SDK 52 (latest, with new architecture), and our entire mobile stack assumes SDK 52 APIs. Going back to 49 would break:

- Most of the `expo-*` packages (different APIs)
- Expo Router (we're on `~4.0.15`, which requires SDK 51+)
- React Native 0.76 with new arch (introduced in SDK 52)
- The build pipeline (`eas build` config)

The npm audit fix isn't actually offering a fix — it's offering "downgrade out of the problem," which trades 24 vulns for an entirely broken codebase.

## Why we tried `npm overrides` and reverted

The `overrides` field in `package.json` lets you force-bump a transitive dependency to a specific version. We tried this with `uuid@^9.0.1`, `@xmldom/xmldom@^0.9.10`, `postcss@^8.5.10`, `tar@^7`, `cacache@^20`, `http-proxy-agent@^9`. npm accepted the override declarations, but the actual installed versions didn't change — the transitive packages declare hard peer constraints (e.g., `xcode` wants `uuid@^7`), and npm fell back to "soft override" mode where it leaves the original version installed and just warns.

Forcing through with `--force --legacy-peer-deps` would let the override take effect but risks breaking the build chain in non-obvious ways (a tool calling `uuid.v3()` against a uuid 9 API that doesn't have that signature). Reverting was the right move.

## Why this is tolerable

These vulns are in **build-time tooling**, not in code that runs on user devices. The actual mobile app bundle (the JavaScript that ships to iOS/Android) doesn't include `xcode`, `@xmldom/xmldom`, `tar`, `cacache`, or any of the transitively-flagged Expo CLI internals. Every CVE in the list is exploitable only against:

- A developer running the Expo CLI on their machine
- The CI build environment (ubuntu-latest, isolated per job)

The threat model — a malicious npm package or input causing harm during build — exists but is bounded by the same trust we're already extending to npm itself.

## Plan

1. **Don't run `npm audit fix --force`** in this repo. Add it to the "things not to do without asking" list in CLAUDE.md.
2. **Let Dependabot keep tracking.** Each new alert is data; we re-evaluate when an alert can actually be cleared by a bump that doesn't break the world.
3. **On every Expo SDK bump,** re-run `npm audit` and see what cleared. Most of these will go away when Expo's team bumps `xcode`, `@xmldom/xmldom`, etc. in their own dependency tree.
4. **If a vuln is actually exploitable on a user device,** that's a different conversation — patch immediately. (None of the current ones qualify.)
5. **Dismiss the noisy Dependabot alerts** in the GitHub UI with reason `tolerable_risk` and a link to this doc, so the security tab isn't a flashing red distraction. Re-open if the situation changes.

## What to do when adding a new dep

- Read the dep's own `npm audit` output before adding.
- Check the dep's last-published date and weekly download count — abandoned deps become liabilities.
- Prefer deps that ship to fewer places (a build-time tool is lower-risk than a runtime lib that's bundled into every binary).
- Run `npm run verify` after `npm install` — pre-commit + CI catch obvious breakage; the audit is a quieter signal you have to check on purpose.
