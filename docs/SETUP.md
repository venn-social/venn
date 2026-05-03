# Setup Guide

This guide takes you from "fresh laptop" to "Venn app running in the simulator and your first PR opened." Read it top to bottom. It takes about 45 minutes the first time.

If something goes wrong, the fix is almost always in [Troubleshooting](#troubleshooting) at the bottom.

---

## What you need

- A **Mac** (Apple Silicon recommended). Building iOS apps requires macOS.
- About **30 GB free disk space** (Xcode is large).
- A **GitHub account** with access to [venn-social/venn](https://github.com/venn-social/venn).
- A **GitHub SSH key** ([guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)).

---

## 1. Install Xcode

1. Open the App Store, search for **Xcode**, click Get. (~7 GB; takes 30+ minutes on slow connections.)
2. Open Xcode once it's installed and accept the license.
3. In a Terminal:

```bash
sudo xcode-select -s /Applications/Xcode.app
xcodebuild -version    # should print "Xcode 26.x" or later
```

If it prints a different Xcode path, point `xcode-select` at the right one.

---

## 2. Install Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen instructions to add Homebrew to your shell (the installer prints exactly what to copy/paste).

Verify:

```bash
brew --version    # should print "Homebrew 4.x"
```

---

## 3. Install Node + Git

```bash
brew install node@20 git gh
brew link node@20
```

Verify:

```bash
node --version    # v20.x.x
npm --version     # 10.x or later
git --version     # 2.40+
gh --version      # any 2.x
```

`gh` is the GitHub CLI — handy for opening PRs from the terminal.

---

## 4. Install the Swift toolchain helpers

```bash
brew install xcodegen swiftlint swiftformat xcbeautify
```

What each does:

- **xcodegen** — generates `Venn.xcodeproj` from `ios/project.yml`. We don't commit the `.xcodeproj`.
- **swiftlint** — strict lint rules for Swift code (requires full Xcode, which is why we installed it first).
- **swiftformat** — auto-formats Swift code.
- **xcbeautify** — pretty output from `xcodebuild` (the raw output is unreadable).

Verify:

```bash
xcodegen --version
swiftlint version
swiftformat --version
xcbeautify --version
```

---

## 5. Clone the repo

```bash
mkdir -p ~/GitProjects && cd ~/GitProjects
git clone git@github.com:venn-social/venn.git
cd venn
```

If you see "Permission denied (publickey)", your GitHub SSH key isn't set up. Follow the [GitHub guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh).

---

## 6. Run setup

```bash
make setup
```

This installs node tooling (husky, commitlint, prettier), runs `xcodegen` to create the Xcode project, and verifies your tools are installed.

If `make setup` fails, jump to [Troubleshooting](#troubleshooting).

---

## 7. Add your environment variables

```bash
cp .env.example .env
```

Open `.env` in your editor and fill in real values. Get them from another collaborator (or from the Supabase dashboard if you're the owner). At minimum you need:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The other vars (Sentry DSN, PostHog API key) are optional — leave them blank for local development.

**Never commit `.env`.** It's in `.gitignore`. The build script reads it at compile time and writes derived values into `Resources/GeneratedConfig.xcconfig` (also gitignored).

---

## 8. Open the project in Xcode

```bash
xed ios/Venn.xcodeproj
```

Or `open ios/Venn.xcodeproj`. Xcode will:

1. Resolve the Swift Package Manager dependencies (Supabase, Sentry, PostHog, ...). This takes 1–2 minutes the first time.
2. Index the project. The status bar shows progress.

Once indexing is done:

1. Pick an iPhone simulator from the scheme menu (e.g. **iPhone 17 Pro**).
2. Hit **⌘R** to build and run.

The app should launch and show "venn" with a colored icon.

---

## 9. Run the tests

From the repo root:

```bash
make test
```

You should see all tests pass. If they don't, [Troubleshooting](#troubleshooting).

---

## 10. Open your first PR

Pick something small — typo in a doc, fix a comment, anything. Then:

```bash
git checkout -b docs/your-name-fix-typo
# make your change
git add .
git commit -m "docs: fix typo in <file>"
git push -u origin docs/your-name-fix-typo
gh pr create
```

Fill in the PR template. Wait for CI. Once green, ping a CODEOWNER for review.

---

## Troubleshooting

### `make setup` fails with "command not found: xcodegen"

Homebrew may not be on your PATH. Run:

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
source ~/.zshrc
```

Then try `make setup` again.

### `xcodegen generate` complains about a missing `project.yml`

You need to be in the `ios/` directory or run via `make project` from the repo root.

### Xcode says "No such module 'Supabase'"

Swift Package Manager hasn't resolved yet. In Xcode: **File → Packages → Reset Package Caches**. Then **File → Packages → Resolve Package Versions**.

### App crashes on launch with "Missing SUPABASE_URL"

Your `.env` is missing or empty. Run `cp .env.example .env` and fill in real values, then **Product → Clean Build Folder** in Xcode (⇧⌘K) and rebuild.

### Tests fail with "iPhone 17 Pro not available"

Open Xcode → Settings → Platforms → iOS, install the latest simulator runtime. Or change the destination in `Makefile` to a simulator you do have:

```makefile
DESTINATION := platform=iOS Simulator,name=iPhone 16,OS=latest
```

### "Cannot find Xcode 26"

You're on an older Xcode. Update via App Store. iOS 26 is required.

### Pre-commit hook fails

Read the actual error. Usually:

- **SwiftLint error**: fix the lint warning.
- **SwiftFormat**: the hook reformats in place — `git add .` and commit again.
- **Commitlint**: your commit message doesn't follow Conventional Commits.

### "Husky hook not running"

```bash
npm run prepare
```

### CI passes but my local `make test` fails

You probably have stale derived data. Run `make clean && make test`.

---

## What to read next

- [`CODING_STANDARDS.md`](./CODING_STANDARDS.md) — what we expect in PRs.
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — where things go and why.
- [`WORKFLOW.md`](./WORKFLOW.md) — the full git/PR flow.
- [`DATABASE.md`](./DATABASE.md) — Supabase migrations workflow.
