# Releasing to TestFlight

How a build gets from `main` to testers' phones. The pipeline is **Fastlane driven from GitHub Actions** — see [ADR 0009](./decisions/0009-fastlane-on-github-actions-for-testflight.md) for why.

> **Status (2026-06-26):** the pipeline is **blocked on the Apple Developer account**. Nothing below the "One-time setup" line can be built or tested until the account is active — signing can only be debugged against the real account. This doc is the checklist to get there. Once setup is done, Claude wires the `fastlane/` config + the release workflow and we cut the first build.

---

## One-time setup (the human prerequisites)

These are the things **only a person with the Apple account can do**. Do them in order; each unblocks the next. Budget ~1–2 hours of clicking plus 24–48h for Apple to activate enrollment.

### 1. Enroll in the Apple Developer Program

- Go to <https://developer.apple.com/programs/enroll/> and enroll as the **organization** "Venn" (or as an individual to start — can convert later). **$99/yr.**
- Activation takes ~24–48h. **This is the critical-path item for December — start it first.**
- Once active, note the **Team ID** (Apple Developer → Membership details). It looks like `A1B2C3D4E5`.

### 2. Register the app in App Store Connect

- <https://appstoreconnect.apple.com> → **Apps → +** → New App.
- Platform **iOS**, name **Venn**, primary language, bundle ID **`social.venn.app`** (register it in the Developer portal first if it's not in the dropdown), SKU `venn-ios`.
- No need to fill store metadata yet — TestFlight only needs the app record to exist.

### 3. Create an App Store Connect API key (for CI uploads)

CI uploads with an API key, not a personal Apple ID (more robust, no 2FA prompts).

- App Store Connect → **Users and Access → Integrations → App Store Connect API → +**.
- Role **App Manager** (or Admin). Name it `github-actions-ci`.
- **Download the `.p8` key file — you only get one chance.** Note the **Key ID** and the **Issuer ID** (shown above the keys table).

### 4. Create a private repo for Fastlane Match

Match stores the signing certificates + provisioning profiles, encrypted, in a private git repo so CI (and every maintainer) shares the same ones.

- Create a **private** repo: `venn-social/certificates` (empty is fine).
- Pick a strong **Match passphrase** and save it in the team password manager — it encrypts the contents.

### 5. Add the GitHub Actions secrets

Repo → **Settings → Secrets and variables → Actions → New repository secret**. Add:

| Secret            | Value                                                                             |
| ----------------- | --------------------------------------------------------------------------------- |
| `APPLE_TEAM_ID`   | Team ID from step 1 (e.g. `A1B2C3D4E5`)                                           |
| `ASC_KEY_ID`      | Key ID from step 3                                                                |
| `ASC_ISSUER_ID`   | Issuer ID from step 3                                                             |
| `ASC_KEY_P8`      | Contents of the `.p8` file, base64-encoded: `base64 -i AuthKey_XXXX.p8 \| pbcopy` |
| `MATCH_PASSWORD`  | The passphrase from step 4                                                        |
| `MATCH_GIT_URL`   | `https://github.com/venn-social/certificates.git`                                 |
| `MATCH_GIT_TOKEN` | A fine-grained PAT (or deploy key) with read/write to the `certificates` repo     |

> You can hand these values to Claude in chat and it will set them with `gh secret set …` for you, or add them in the GitHub UI yourself. They are write-only once set.

---

## What Claude builds once the above is done

When the account is active and the secrets exist, Claude adds (and verifies against the real account):

- **`fastlane/`** — `Appfile` (bundle id + team), `Matchfile` (the certs repo), and a `Fastfile` with a `beta` lane: `match(type: "appstore")` → `build_app` → `upload_to_testflight`.
- **`ExportOptions`** + Release signing settings in `ios/project.yml` (`DEVELOPMENT_TEAM`, manual signing with the Match profile).
- **`.github/workflows/testflight.yml`** — triggered on a `v*` tag and via manual `workflow_dispatch`; checks out, installs Fastlane, decodes the API key, runs `fastlane beta`.
- **`Gemfile`** pinning the `fastlane` gem.

The first run will likely need a few iterations to get signing exactly right — that's normal and expected.

---

## Cutting a release (once the pipeline exists)

1. Bump `MARKETING_VERSION` (and let CI auto-increment the build number) in `ios/project.yml`.
2. Tag the commit: `git tag v0.1.0 && git push origin v0.1.0`.
3. The `testflight.yml` workflow archives, signs, and uploads to TestFlight.
4. The build appears in App Store Connect → TestFlight after Apple finishes processing (~5–15 min); add it to a tester group.
