# Git + PR Workflow

This is the detailed version of the workflow summarized in [`.github/CONTRIBUTING.md`](../.github/CONTRIBUTING.md).

## The mental model

`main` is sacred. Every change rides in on a feature branch, gets reviewed, passes CI, and squash-merges in. Nothing else lands on `main`.

```
main         o───o───o───o───o─────o───o───  (always green)
                       \                /
feat/auth-screen        o───o───o───o─/      (your work; squashed on merge)
```

## The full flow, step by step

### 1. Sync `main`

```bash
git checkout main
git pull origin main
```

### 2. Create a Notion task

Before writing code, create or find a Notion task in the [tasks DB](https://notion.so/34ac60c854a2800ca903ef85907bec3e):

- **Task name:** lowercase, short, action-oriented (`add auth screen`, `fix feed crash`).
- **Task type:** `tech` for code work; `branding` for marketing-site work.
- **Status:** `In progress`.
- **Description:** what you're doing and why.

Claude does this automatically when you start a coding task.

### 3. Branch

```bash
git checkout -b feat/short-description
# or fix/, refactor/, docs/, ci/, chore/...
```

Branch name format: `<type>/<kebab-case-description>`. Match the conventional-commit type.

### 4. Code

Match the existing folder structure. New feature → new folder under `ios/Venn/Features/<Name>/` with `<Name>Service.swift`, `<Name>ViewModel.swift`, `<Name>View.swift`.

Don't fight SwiftLint or SwiftFormat — they're configured to match the project's style. If you really think a rule is wrong, raise it in a PR; don't disable it inline.

### 5. Commit

Conventional Commits format: `<type>(<scope>): <subject>`.

| Type       | When to use                                            |
| ---------- | ------------------------------------------------------ |
| `feat`     | New user-facing feature                                |
| `fix`      | Bug fix                                                |
| `refactor` | Code restructure, no behavior change                   |
| `perf`     | Performance improvement                                |
| `style`    | Formatting/whitespace only (rare; SwiftFormat handles) |
| `test`     | Adding or fixing tests                                 |
| `docs`     | Documentation only                                     |
| `build`    | Project / build system / dependencies                  |
| `ci`       | CI configuration                                       |
| `chore`    | Anything else (deletions, version bumps)               |
| `revert`   | Reverts a previous commit                              |

Examples:

```text
feat(auth): add sign-in with Apple
fix(feed): crash when post body is empty
refactor(profile): extract overlap calculation to service
chore(deps): bump supabase-swift to 2.10.0
ci: cache SwiftPM dependencies between runs
```

The pre-commit hook runs SwiftLint and SwiftFormat on staged files. The commit-msg hook validates the message against commitlint.

### 6. Push

```bash
git push -u origin feat/short-description
```

### 7. Open a PR

```bash
gh pr create
```

Or click the "Compare & pull request" button on GitHub. Fill in the PR template. CI runs automatically.

### 8. CI must pass

Four jobs run on every PR:

- **Lint** — SwiftLint in strict mode.
- **Format check (Swift)** — SwiftFormat in lint mode.
- **Format check (docs)** — Prettier on Markdown / JSON / YAML.
- **Tests** — Swift Testing + XCUITest in the iOS Simulator.

Plus:

- **Commit messages** — commitlint validates each commit follows Conventional Commits.
- **Secret scan (trufflehog)** — fails if any committed file looks like a credential.

If any fail, click through to the run, fix the issue, push again. Don't merge through a red CI.

### 9. Review

At least one approval from a CODEOWNER. Reviewers check the rubric in [`CODING_STANDARDS.md`](./CODING_STANDARDS.md#pr-review-rubric).

### 10. Squash merge

`main` keeps a clean linear history. Each PR becomes one commit on `main`. The PR title becomes the commit subject — make sure it's a valid Conventional Commit.

### 11. Update Notion

Set the task's `PR Link` field to the merged PR URL and `Status` to `Done`. Claude does this automatically.

---

## Reviewing a PR without running Xcode

Every successful CI run uploads the simulator-built `Venn.app` as an artifact, so reviewers can install the build on a Simulator without checking out the branch.

1. Open the PR's **Checks** tab → click the **CI** workflow → scroll to **Artifacts** at the bottom.
2. Download `venn-<sha>.zip` and unzip it. You get `Venn.app`.
3. Boot a simulator (`xcrun simctl boot "iPhone 17 Pro"` or open Simulator.app and pick a device).
4. Drag `Venn.app` onto the running simulator window — it installs automatically. Or run:

   ```bash
   xcrun simctl install booted Venn.app
   xcrun simctl launch booted social.venn.app
   ```

The artifact is built for arm64 iOS Simulator (matches Apple Silicon Macs). Retention is 7 days; older artifacts auto-expire.

This is a stopgap until per-PR TestFlight builds land — blocked on the Apple Developer enrollment ([`README.md`](../README.md) "Future considerations").

---

## Troubleshooting

### "Pre-commit hook failed"

Read the output. Usually:

- **SwiftLint error:** fix the lint issue. If it's a false positive, talk to the team before disabling.
- **SwiftFormat:** the hook formats in place. Just `git add .` again and commit.
- **Prettier:** same — formats in place.

### "Commit message rejected"

Your commit message doesn't follow Conventional Commits. Run `git commit --amend` and fix the subject line.

### "CI Tests are failing but they pass locally"

- Run `make clean && make test` locally first. Stale `DerivedData` masks bugs.
- If it's only failing in CI, it's likely a Simulator-version mismatch. Check the destination in `.github/workflows/ci.yml` matches what you have locally.
- If it's a flake, push an empty commit (`git commit --allow-empty -m "ci: retrigger"`) to re-run.

### "I committed to `main` by accident"

```bash
git reset HEAD~1                      # un-commit, keep changes staged
git checkout -b feat/my-thing
git add . && git commit -m "feat(...): ..."
git push -u origin feat/my-thing
```

If you've already pushed to main, **stop and ask** — undoing a public commit affects everyone. Don't force-push to main yourself.

### "I need to rebase onto a moved `main`"

```bash
git fetch origin
git rebase origin/main
# Resolve conflicts file by file, then:
git add .
git rebase --continue
git push --force-with-lease
```

`--force-with-lease` is safer than `--force` — it refuses if someone else pushed to your branch.

### "I want to undo a merge to `main`"

Don't undo it on `main`. Open a PR with a `revert:` commit:

```bash
git revert <merge-commit-sha> -m 1
```

This is reversible and visible in history.
