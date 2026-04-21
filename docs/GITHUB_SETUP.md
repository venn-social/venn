# One-time GitHub setup (for the repo owner)

The repo files enforce most of the rules, but a few things live on GitHub.com and must be configured through the web UI. Do these once, right after pushing the initial scaffold.

If you skip this, nothing in the rules document is actually enforced — anyone can still push to `main` directly, bypass CI, and merge PRs without review. Do this first.

---

## 1. Push the scaffold to GitHub

You've cloned the scaffold locally (or Claude handed it to you). From the repo root:

```bash
cd ~/path/to/venn
git init
git add .
git commit -m "chore: initial scaffold"
git branch -M main
git remote add origin https://github.com/venn-social/venn.git
git push -u origin main
```

---

## 2. Install your dependencies (so Husky sets itself up)

```bash
nvm use
npm install
```

The `prepare` script in `package.json` runs `husky` on install, which wires up the pre-commit hooks.

---

## 3. Set up branch protection on `main`

Go to: **github.com/venn-social/venn → Settings → Branches → Add branch ruleset**.

Create a ruleset with these settings:

- **Name**: `protect-main`
- **Enforcement status**: Active
- **Target branches**: include `main`
- **Rules** (enable all of these):
  - ✅ Restrict deletions
  - ✅ Require a pull request before merging
    - Required approvals: `1` (bump to `2` once the team is bigger)
    - ✅ Dismiss stale pull request approvals when new commits are pushed
    - ✅ Require review from Code Owners
    - ✅ Require conversation resolution before merging
  - ✅ Require status checks to pass
    - ✅ Require branches to be up to date before merging
    - Add these required checks (they'll appear in the dropdown after your first CI run):
      - `Lint`
      - `Format check`
      - `Type check`
      - `Tests`
      - `Check commit messages`
  - ✅ Block force pushes
  - ✅ Require linear history (forces squash or rebase merges)

Save.

> **Note:** You may not see the status checks in the dropdown until a PR has run CI at least once. If they're missing, open a throwaway PR (see step 6), let CI run, then come back and add the checks.

---

## 4. Set "Squash merging" as the only allowed merge method

Settings → General → Pull Requests:

- ✅ Allow squash merging
  - Default commit message: "Pull request title"
- ❌ Allow merge commits (uncheck)
- ❌ Allow rebase merging (uncheck)
- ✅ Automatically delete head branches

This keeps `main`'s history clean: one commit per PR.

---

## 5. Add your co-founders

Settings → Collaborators and teams → Add people.

Grant them the **Write** role (lets them push branches and open PRs, but not edit settings). Save the **Admin** role for repo owners only.

Once they've accepted, edit `.github/CODEOWNERS` to list their GitHub usernames next to the paths they own.

---

## 6. Open a throwaway PR to verify everything

```bash
git checkout -b chore/verify-setup
# Make a trivial change — e.g., edit a word in README.md.
git add README.md
git commit -m "chore: verify repo setup"
git push -u origin chore/verify-setup
gh pr create --fill
```

On the PR page, confirm:

- ✅ CI jobs (`Lint`, `Format check`, `Type check`, `Tests`, `Check commit messages`) all run and pass.
- ✅ The PR cannot be merged without approval (the merge button is disabled).
- ✅ Ask a co-founder to approve. After approval, the button unlocks.
- ✅ Only "Squash and merge" is offered as the merge button.
- ✅ After merge, the branch is auto-deleted.

If every box above is checked, you're set up. If any fail, revisit Step 3.

---

## 7. Enable security features (2 minutes)

Settings → Code security and analysis:

- ✅ Dependabot alerts
- ✅ Dependabot security updates
- ✅ Secret scanning
- ✅ Push protection (blocks commits that contain secrets)

These are free on public repos (and on most Team plans for private ones). Turn them all on.

---

## 8. Invite the team to the workflow chat

Create a `#venn-eng` channel in Slack/Discord and:

- Pin `SETUP.md` and `CONTRIBUTING.md` as welcome reading.
- Connect the GitHub app so PR notifications post in-channel. That way reviews don't get lost.

---

Once you're done, every rule in [`CONTRIBUTING.md`](../CONTRIBUTING.md) is enforced by the tooling. Nobody — including you — can push broken code to `main` by accident.
