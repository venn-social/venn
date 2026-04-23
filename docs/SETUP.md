# Setup Guide

This guide takes you from "I have never coded before" to "The Venn app is running on my phone and I just opened my first pull request." Read it from top to bottom. It takes about 45 minutes the first time.

If something goes wrong, don't panic — the fix is almost always in the troubleshooting section at the bottom.

---

## Step 1 — Install the tools (one-time, per person)

You need four things on your computer. Install them in this order.

### 1a. Node.js (via `nvm`)

Node is the runtime that powers our build tools, our test runner, and the Expo dev server. We manage which version of Node is installed using `nvm` ("Node Version Manager") so every teammate is on the same version — that avoids a whole class of "works on my machine" bugs.

**On macOS or Linux:**

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
```

Close and reopen your terminal, then run:

```bash
nvm install 20.11.1
nvm use 20.11.1
node --version   # should print v20.11.1
```

**On Windows:** install [`nvm-windows`](https://github.com/coreybutler/nvm-windows/releases) (grab `nvm-setup.exe` from the latest release), then in PowerShell:

```powershell
nvm install 20.11.1
nvm use 20.11.1
node --version
```

### 1b. Git

Git is how you save, share, and collaborate on code.

- macOS: `xcode-select --install` (installs Git and command-line tools).
- Windows: download [Git for Windows](https://git-scm.com/download/win) and run the installer with default options.
- Linux: `sudo apt install git` (Ubuntu/Debian) or `sudo dnf install git` (Fedora).

Then configure your name and email (use the same email you use for GitHub):

```bash
git config --global user.name "[NAME]"
git config --global user.email "[EMAIL]"
git config --global init.defaultBranch main
```

### 1c. GitHub CLI (`gh`)

The GitHub CLI lets you open PRs, review them, and merge from the terminal. Download from [cli.github.com](https://cli.github.com/) and after install:

```bash
gh auth login
```

Pick: GitHub.com → HTTPS → Authenticate with your browser. Follow the prompts.

### 1d. The Expo Go app (on your phone)

This is the iPhone / Android app that lets you run Venn on your phone while you develop. You don't need an Apple Developer account. You don't need a Mac. You don't need an Android emulator.

- iPhone: install [**Expo Go**](https://apps.apple.com/app/expo-go/id982107779) from the App Store.
- Android: install [**Expo Go**](https://play.google.com/store/apps/details?id=host.exp.exponent) from the Play Store.

### 1e. (Optional, for later) A code editor

[Visual Studio Code](https://code.visualstudio.com/) or [Cursor](https://cursor.com) (an AI-enhanced fork of VS Code). Either one will auto-install the right extensions the first time you open the repo, because this repo has a `.vscode/extensions.json` that recommends them.

---

## Step 2 — Clone the repo

"Cloning" means downloading a copy of the code to your computer.

```bash
cd ~                                         # pick wherever you want it to live
gh repo clone venn-social/venn                     # this is our repo
cd venn
```

You should now see files like `README.md`, `package.json`, and folders like `apps/` and `packages/`.

---

## Step 3 — Install dependencies

Our app depends on hundreds of small libraries (React, React Native, Expo, Supabase, etc.). Install all of them in one shot:

```bash
nvm use            # switch to the Node version this repo expects
npm install        # installs everything. Takes 2–5 minutes the first time.
```

When that finishes, you should have a new `node_modules/` folder. Don't worry about what's inside it — and definitely don't commit it. (`.gitignore` already blocks it from being committed.)

---

## Step 4 — Set up your environment variables

The app needs to know how to talk to our backend (Supabase). Those URLs and keys live in an `.env` file that each person creates themselves — we never commit it, because secrets shouldn't live in git.

```bash
cd apps/mobile
cp .env.example .env
```

Now open `apps/mobile/.env` in your editor and fill in the Supabase URL and anon key. (The project owner sets up the Supabase project once and shares those values over a secure channel — Slack DM, 1Password, etc. Never paste them into a public chat or commit them to git.)

> **Don't have Supabase set up yet?** See [`docs/SUPABASE_SETUP.md`](./SUPABASE_SETUP.md) for the 5-minute guide to creating the project.

---

## Step 5 — Run the app

From the repo root:

```bash
npm run mobile
```

A QR code will appear in your terminal. On your phone:

- **iPhone**: open the Camera app and point it at the QR code. Tap the notification banner to open in Expo Go.
- **Android**: open the Expo Go app and tap "Scan QR code."

Your phone connects to your laptop, downloads the JavaScript bundle, and shows the app. Edit a file in `apps/mobile/src/app/(tabs)/index.tsx`, save, and watch the app reload instantly on your phone. That's the full dev loop.

---

## Step 6 — Open your first pull request

Never push code directly to the `main` branch. Every change goes through the branch → PR → review → merge flow. Here it is end to end:

```bash
# 1. Make sure you're up to date.
git checkout main
git pull

# 2. Create a new branch for your change. Name it after what you're doing.
#    Pattern: <your-name>/<short-description>  OR  feat/<short-description>
git checkout -b charles/fix-typo-in-readme

# 3. Make some edits. Save the files.

# 4. Check what you changed.
git status
git diff

# 5. Verify your change doesn't break anything.
npm run verify    # runs lint + format check + typecheck + tests

# 6. Stage and commit. The commit message MUST follow the convention.
#    Format: <type>(<scope>): <short summary>
#    Types:  feat, fix, docs, style, refactor, perf, test, build, ci, chore
git add README.md
git commit -m "docs: fix typo in setup guide"

# 7. Push your branch to GitHub.
git push -u origin charles/fix-typo-in-readme

# 8. Open a PR.
gh pr create --fill
#    ^ opens your browser with a PR template ready to edit.

# 9. Request a review from at least one teammate.
#    Wait for approval. CI must pass (all green checkmarks).
#    Address review comments by pushing more commits to the same branch.

# 10. When approved + CI passes, merge via the GitHub UI ("Squash and merge").

# 11. Clean up.
git checkout main
git pull
git branch -d charles/fix-typo-in-readme
```

Your first PR is the one you want to keep small — maybe fixing a typo in this setup guide, or adding a comment somewhere. That way you go through the whole workflow without worrying about the code being complicated.

---

## Troubleshooting

<details>
<summary><strong>"nvm: command not found"</strong></summary>

Close the terminal and open a new one. If it still doesn't work, your shell startup file (`.zshrc` on Mac, `.bashrc` on Linux) may be missing the nvm snippet. Add this at the bottom:

```bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
```

Save and open a new terminal.

</details>

<details>
<summary><strong>The QR code scans but the app hangs on "Downloading JavaScript bundle…"</strong></summary>

Your phone and laptop must be on the same Wi-Fi network. Corporate Wi-Fi often blocks the connection. If that's the case, run `npm run mobile -- --tunnel` instead; it routes through Expo's servers and works on any network.

</details>

<details>
<summary><strong>"Missing required environment variable: EXPO_PUBLIC_SUPABASE_URL"</strong></summary>

You skipped Step 4. Go back and create `apps/mobile/.env` from the example.

</details>

<details>
<summary><strong>`npm install` fails with a permission error</strong></summary>

You probably ran it with `sudo` at some point and broke the permissions on `~/.npm`. Fix with:

```bash
sudo chown -R $(whoami) ~/.npm
```

Then delete `node_modules` and re-run `npm install` _without_ sudo.

</details>

<details>
<summary><strong>"Husky isn't running on commit"</strong></summary>

Run `npm install` again. Husky installs itself via the `prepare` script, but only when you install from the repo root.

</details>

---

## What's next

- Read [`CONTRIBUTING.md`](../.github/CONTRIBUTING.md) for the day-to-day workflow.
- Read [`docs/WORKFLOW.md`](./WORKFLOW.md) for the detailed branch/PR/review process.
- Read [`docs/ARCHITECTURE.md`](./ARCHITECTURE.md) to understand _why_ the code is organized this way.
- Skim [`docs/CODING_STANDARDS.md`](./CODING_STANDARDS.md) to see the patterns and anti-patterns we watch for.
- If you're a repo owner, do [`docs/GITHUB_SETUP.md`](./GITHUB_SETUP.md) once to lock down branch protection.
