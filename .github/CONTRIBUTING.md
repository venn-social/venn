# Contributing to Venn

This doc is for people who've already finished [SETUP.md](../docs/SETUP.md) and want to ship code.

## The short version

1. `git pull` on `main`.
2. `git checkout -b your-name/what-youre-doing`.
3. Make changes. Save often.
4. `npm run verify` passes.
5. `git commit -m "feat(scope): short imperative summary"`.
6. `git push -u origin your-name/what-youre-doing`.
7. `gh pr create --fill`.
8. Get one approval + green CI.
9. "Squash and merge" in the GitHub UI.
10. Delete your branch.

The rest of this doc explains each step in more detail.

## Branch names

- `feat/<short-description>` — new user-facing feature.
- `fix/<short-description>` — bug fix.
- `chore/<short-description>` — tooling, docs, refactors.
- `<your-name>/<short-description>` — personal branches, anything.

Good: `feat/pull-to-refresh`, `charles/clean-up-theme-tokens`.
Bad: `new-branch`, `test`, `charles-work`.

## Commit messages (Conventional Commits)

Format: `<type>(<optional scope>): <subject>`

- `type` is one of: `feat` | `fix` | `docs` | `style` | `refactor` | `perf` | `test` | `build` | `ci` | `chore` | `revert`.
- `scope` (optional) is the area of the codebase, like `auth` or `feed`.
- `subject` is a short, lowercase, imperative-mood description. No period at the end.

Good:

- `feat(auth): add sign-in with Apple`
- `fix(feed): crash when post has no caption`
- `docs: clarify how to run tests`
- `chore(deps): bump expo to 52.0.1`

Bad (will be rejected by commitlint):

- `Updated stuff`
- `WIP`
- `Fixed the bug.`
- `Feat: new feature.`

If you botched a commit message locally, amend it before pushing:

```bash
git commit --amend
```

## Before you open a PR

Run the full local check:

```bash
npm run verify
```

That runs, in order: `lint` → `format:check` → `typecheck` → `test`. If any of these fail, CI will fail too — fix them locally first. It's faster.

Most issues auto-fix:

```bash
npm run lint:fix
npm run format
```

## Pull requests

### What makes a good PR

- **Small.** Under ~400 lines changed is ideal. Huge PRs don't get reviewed well.
- **One thing.** If you find yourself writing "also fixed X and Y," split the PR.
- **Described.** Fill out the PR template. Say _what_ and _why_, not _how_.
- **Tested.** New logic gets a unit test. UI changes get a screenshot or screen recording.
- **Self-reviewed.** Before requesting review, re-read your own diff on GitHub. You'll catch half the issues yourself.

### Getting a review

- Assign at least one reviewer (`gh pr edit --add-reviewer <username>`).
- CODEOWNERS auto-assigns the right person for sensitive paths.
- If a PR sits idle for more than a day, gently @-mention the reviewer in Slack / Discord.

### Responding to review comments

- Push new commits to the same branch — don't force-push unless you have to.
- Reply "done" to each addressed comment, or push back if you disagree.
- Ask questions if a review comment confuses you. Reviewers want to help.

### Merging

- Use **"Squash and merge"** in the GitHub UI. This keeps `main`'s history clean: one commit per PR.
- The squash commit message defaults to the PR title. Make sure the PR title follows conventional-commit format.
- After merging, delete the branch (GitHub offers a button).

## What not to do

- Don't commit `.env`, API keys, or any other secrets.
- Don't commit generated files (`node_modules`, `dist`, `build`).
- Don't commit commented-out code. If you're unsure whether to delete something, delete it — git remembers.
- Don't add libraries without a reason. Every new dependency is a future security update, a larger bundle, and more to debug.
- Don't use `--no-verify` to skip commit hooks except in a real emergency.

## When you're stuck

Read [`docs/CODING_STANDARDS.md`](../docs/CODING_STANDARDS.md) and [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md). Then ask in the team chat.
