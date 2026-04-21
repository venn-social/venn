# Git + PR Workflow

This is the detailed version of the workflow summarized in [`CONTRIBUTING.md`](../CONTRIBUTING.md). If you want to understand _why_ we do each step, read this.

## The mental model

`main` is the **only** branch that matters. Everything else is temporary scratch space.

The rules:

1. `main` is always "green" — it builds, tests pass, it's ready to ship.
2. You never edit `main` directly. You edit a branch, open a PR, get it reviewed, and merge.
3. Once merged, the branch is deleted.

That's it. Every single change to Venn's code, no matter how small, follows that pattern.

## The full walkthrough

### 1. Sync with `main`

Before starting anything, make sure your local `main` matches GitHub's `main`.

```bash
git checkout main
git pull --rebase
```

`--rebase` keeps history linear. You want this.

### 2. Create a branch

Name it after what you're doing, not after yourself (usually):

```bash
git checkout -b feat/signup-validation
```

The `-b` flag means "create it if it doesn't exist." After this, `git branch` shows a `*` next to `feat/signup-validation`.

### 3. Make changes

Edit files. Save. The dev server auto-reloads.

Run `git status` periodically to remind yourself what's changed. Run `git diff` to see the actual changes.

### 4. Commit often, in logical chunks

One commit = one idea. If you're working on signup validation and you also happen to fix a typo in the button label, that's two commits:

```bash
git add apps/mobile/src/app/auth/signup.tsx
git commit -m "feat(auth): validate username before signup"

git add apps/mobile/src/components/ui/Button.tsx
git commit -m "fix(ui): correct capitalization of 'Sign up' button label"
```

Don't pile everything into one giant "did a bunch of stuff" commit. Smaller commits are easier to review, easier to revert, and easier to read in history.

### 5. Verify locally

Before pushing, run:

```bash
npm run verify
```

This runs the same checks that CI will run on your PR. Catching issues locally saves you the round-trip of "push → CI fails → fix → push again."

If something fails, most issues are auto-fixable:

```bash
npm run lint:fix    # fix lint issues
npm run format      # fix formatting
```

For typecheck and test failures, you have to fix them by hand (they're usually real bugs).

### 6. Push your branch

```bash
git push -u origin feat/signup-validation
```

The `-u origin` part tells git "remember that this branch tracks `origin/feat/signup-validation`." After the first push, you can just say `git push`.

### 7. Open a pull request

```bash
gh pr create --fill
```

`--fill` pre-populates the title and body from your commits. Edit them in your browser so they match the PR template.

Good PR title examples:

- `feat(auth): validate username before signup`
- `fix(feed): handle empty-caption edge case`

Bad:

- `My changes`
- `WIP`
- `Updates`

### 8. Get a review

- Assign one or more reviewers.
- Wait for CI to go green (all the checkmarks on the PR page).
- Reviewers leave comments. Respond to each one — either push a fix or explain why you disagree.

PRs usually need one approval before merging. For critical paths (auth, CI config, dependencies) require at least two.

### 9. Merge

Use **"Squash and merge"** from the GitHub UI. This collapses all the commits on your branch into one clean commit on `main`.

Why squash?

- `main` history stays legible: one commit per feature, not 17 "fix typo" commits.
- If something breaks, reverting is one `git revert`, not seventeen.

### 10. Clean up

After merging:

```bash
git checkout main
git pull --rebase
git branch -d feat/signup-validation
```

GitHub will also offer a "Delete branch" button. Click it.

## Common scenarios

### "Someone else merged to `main` while my PR was open, and now there are conflicts."

```bash
git checkout main
git pull --rebase
git checkout feat/signup-validation
git rebase main
# Fix conflicts in your editor. Git tells you which files have conflicts.
git add <conflicted-files>
git rebase --continue
git push --force-with-lease    # required after rebase
```

`--force-with-lease` is a safer version of `--force` — it refuses to push if someone else also pushed to your branch.

### "I committed to `main` by accident."

```bash
# Move your last commit onto a new branch.
git checkout -b my-rescue-branch
# Go back to main and reset it.
git checkout main
git reset --hard origin/main
git checkout my-rescue-branch
```

Then push the rescue branch and open a PR as normal.

### "I need to pull someone else's PR branch to test it locally."

```bash
gh pr checkout 42    # pulls PR #42 and switches to its branch
```

### "My pre-commit hook is being a pain and I need to bypass it this ONE time."

```bash
git commit --no-verify -m "fix: bypass hook because of <reason>"
```

Don't make this a habit. If you find yourself doing this often, the hook is too strict (fix the config) or the codebase is broken (fix the code).

## Keyboard shortcuts to memorize

- `git status` — what have I changed?
- `git diff` — show me the changes.
- `git log --oneline -10` — last 10 commits.
- `git checkout -` — switch to the previous branch (like `cd -`).
- `git branch -d <name>` — delete a branch that's been merged.
- `gh pr create --fill` — open a PR from your current branch.
- `gh pr checkout <number>` — switch to another person's PR.
- `gh pr view --web` — open the current PR in your browser.
