# Setup Guide

This guide takes you from "fresh laptop" to "Venn app running in the simulator, Claude as your pair, and your first PR opened." Read it top to bottom. Plan ~90 minutes the first time (most of which is unattended download).

If you're non-technical, that's fine — this guide is written for you. The fastest path is: install [VS Code](#5-install-vs-code-and-the-claude-code-extension) and the [Claude Code extension](#6-install-the-official-claude-plugins) early, then ask Claude to walk you through the rest of this file step by step. ("Open `docs/SETUP.md` and help me work through it from where I am" works.)

If something goes wrong, the fix is almost always in [Troubleshooting](#troubleshooting) at the bottom.

---

## What you need

- A **Mac** (Apple Silicon recommended). Building iOS apps requires macOS.
- About **40 GB free disk space** (Xcode is the bulk).
- A **GitHub account**.
- A **Notion account** (free tier is fine).
- An **Anthropic account** for Claude Code (free trial available; the paid plan unlocks longer sessions and Opus).

You'll also need access to the project itself — see [step 0](#0-get-access).

---

## 0. Get access

Before installing anything, ping Charles (`@cslmn`, chmsalomon@gmail.com) with:

- Your **GitHub username** — he'll add you to the `venn-social` GitHub org and to [`CODEOWNERS`](../.github/CODEOWNERS) if you'll be reviewing PRs.
- Your **Notion email** — he'll invite you to [Venn HQ](https://www.notion.so/HQ-34ac60c854a2805fa3b9cc6da0380285) (the workspace where every task, meeting, and decision lives).
- Your **Apple ID email** — only relevant once we have a paid Apple Developer account; for now you can run the app on your own simulator without it.

While you wait for those invites to land, you can keep working through the rest of this guide.

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

## 3. Install Node + Git + GitHub CLI

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

`gh` is the GitHub CLI. Authenticate it now so future steps just work:

```bash
gh auth login    # pick GitHub.com → SSH → upload key → authenticate via browser
```

This sets up both an SSH key (for `git clone`/`git push`) and an OAuth token (for `gh pr create` etc.) in one go. If you'd rather configure SSH manually, follow GitHub's [SSH key guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) instead.

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

## 5. Install VS Code and the Claude Code extension

Most Swift work happens in Xcode, but **VS Code is where Claude lives** — it's where you'll be having the actual development conversations, editing docs/configs/SQL, and reviewing diffs. Cursor works too if you already use it; the extension is the same.

1. Install **[Visual Studio Code](https://code.visualstudio.com/)** (free).
2. Open VS Code.
3. From the Extensions panel (`⇧⌘X`), search for **"Claude Code"** (publisher: Anthropic) and install it. Sign in with your Anthropic account when prompted.
4. Open the cloned repo in VS Code (you'll do that in step 8) — VS Code will then prompt you to install the project's [recommended extensions](../.vscode/extensions.json) (Prettier, EditorConfig, Swift, GitLens, etc.). Say yes.

> If you're new to Claude Code itself, read the [official docs](https://docs.claude.com/en/docs/claude-code/overview) for the basics — it's a 10-minute read and covers the keyboard shortcuts, slash commands, and how the agent uses your tools.

---

## 6. Install the official Claude plugins

Plugins extend Claude with skills (proven workflows like brainstorming, TDD, debugging) and integrations (Figma, GitHub, Notion). The team uses these — installing them puts your Claude on the same footing as everyone else's.

In any Claude Code session (VS Code or terminal), run:

```text
/plugin marketplace add anthropics/claude-plugins-official
/plugin install superpowers@claude-plugins-official
/plugin install figma@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install frontend-design@claude-plugins-official
/plugin install context7@claude-plugins-official
/plugin install security-guidance@claude-plugins-official
```

What each gives you:

| Plugin              | Why                                                                                                                          |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `superpowers`       | The core skill bundle: brainstorming, TDD, debugging, writing/executing plans, code review.                                  |
| `figma`             | Reads Figma designs and writes back to them. Required because we're [figma-first](./decisions/0008-figma-first-frontend.md). |
| `code-review`       | `/code-review` slash command for structured PR reviews.                                                                      |
| `frontend-design`   | Better defaults for SwiftUI / web component design.                                                                          |
| `context7`          | Up-to-date library docs (Supabase, SwiftUI, etc.) inside the conversation.                                                   |
| `security-guidance` | Surface security considerations during code review.                                                                          |

Restart your Claude Code session for the plugins to register. Then `/help` lists every new skill and slash command that's now available.

---

## 7. Configure the Notion MCP server

The Notion MCP gives Claude direct access to the [Venn Notion HQ](https://www.notion.so/HQ-34ac60c854a2805fa3b9cc6da0380285) so it can create tasks, link PRs, and read meeting notes — exactly the workflow described in [`CLAUDE.md`](../CLAUDE.md) rule 2.

1. **Wait for the Notion invite from step 0** to land — you need to be a member of the workspace before this works.
2. Create a personal Notion integration: go to [notion.so/my-integrations](https://www.notion.so/my-integrations) → **New integration** → name it "claude-yourname", workspace "venn", capabilities: read + update + insert content. Copy the secret (starts with `ntn_`).
3. In Notion HQ, open the [Tasks](https://www.notion.so/34ac60c854a2800ca903ef85907bec3e) and [Meetings](https://www.notion.so/34ac60c854a2801cb5eff8a694dba2d4) databases, click `…` → **Connections** → add your integration. Repeat for any other pages Claude needs to touch.
4. Add the MCP server to your Claude config (`~/.claude/mcp.json`):

```json
{
  "mcpServers": {
    "notion": {
      "command": "npx",
      "args": ["-y", "@notionhq/notion-mcp-server"],
      "env": {
        "OPENAPI_MCP_HEADERS": "{\"Authorization\": \"Bearer YOUR_NTN_TOKEN_HERE\", \"Notion-Version\": \"2025-09-03\"}"
      }
    }
  }
}
```

Replace `YOUR_NTN_TOKEN_HERE` with the secret you just created. Restart Claude Code; `/help` should list `mcp__notion__*` tools.

> **Important:** the `Notion-Version` header must be `2025-09-03`. Earlier values (e.g. `2022-06-28`) break query endpoints.

---

## 8. Clone the repo

```bash
mkdir -p ~/GitProjects && cd ~/GitProjects
git clone git@github.com:venn-social/venn.git
cd venn
code .   # open in VS Code
```

If you see "Permission denied (publickey)", your GitHub SSH key isn't set up — re-run `gh auth login` from step 3.

---

## 9. Run setup

```bash
make setup
```

This installs node tooling (husky, commitlint, prettier), runs `xcodegen` to create the Xcode project, and verifies your tools are installed.

If `make setup` fails, jump to [Troubleshooting](#troubleshooting).

---

## 10. Add your environment variables

```bash
cp .env.example .env
```

Open `.env` in your editor and fill in real values. Ask Charles for them, or — if you're talking to Claude — paste the values into the chat and Claude will write them to `.env` for you (it knows to do this).

At minimum you need:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

The other vars (Sentry DSN, PostHog API key) are optional — leave them blank for local development.

**Never commit `.env`.** It's in `.gitignore`. The build script reads it at compile time and writes derived values into `Resources/GeneratedConfig.xcconfig` (also gitignored).

---

## 11. Open the project in Xcode

```bash
xed ios/Venn.xcodeproj
```

Or `open ios/Venn.xcodeproj`. Xcode will:

1. Resolve the Swift Package Manager dependencies (Supabase, Sentry, PostHog, ...). This takes 1–2 minutes the first time.
2. Index the project. The status bar shows progress.

Once indexing is done:

1. Pick an iPhone simulator from the scheme menu (e.g. **iPhone 17 Pro**).
2. Hit **⌘R** to build and run.

The app should launch and show the "venn" splash, then the auth screen.

---

## 12. Run the tests

From the repo root:

```bash
make test
```

You should see all tests pass. If they don't, see [Troubleshooting](#troubleshooting).

---

## 13. Open your first PR (with Claude)

The point of this whole setup is that Claude can drive most of the workflow. For your first PR, try this:

1. In VS Code, open a new Claude Code session in the venn folder.
2. Ask: **"What's a good first task I could pick up to get familiar with the repo?"** Claude will check Notion, scan the codebase, and suggest something small.
3. Tell it to go ahead. Claude will create the Notion task, branch, write the change, run `make verify`, push, and open the PR.
4. Review the diff yourself (you're the human in the loop), edit anything that doesn't read right, and ping a CODEOWNER.

Or, if you'd rather do it manually:

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

### Claude doesn't see any of the new plugin skills

Restart Claude Code (close the VS Code window with the Claude panel and reopen). Run `/help` to confirm the skills are loaded. If they still aren't:

```bash
claude /plugin list                          # what's installed
ls ~/.claude/plugins/installed_plugins.json  # confirm the file exists
```

If it's empty, re-run the `/plugin install …` commands from [step 6](#6-install-the-official-claude-plugins).

### Notion MCP returns "Invalid request URL"

Your `Notion-Version` is wrong. It must be exactly `2025-09-03` — earlier API versions don't support the data-source query endpoints Claude uses. Update `~/.claude/mcp.json` and restart Claude Code.

### Notion MCP returns "Unauthorized"

The integration token (`ntn_...`) is correct, but you forgot to **share the page with the integration**. Open the database in Notion → `…` menu → **Connections** → add your integration. Repeat for every database/page you want Claude to access.

---

## What to read next

- [`../CLAUDE.md`](../CLAUDE.md) — the project brief that gets loaded at the start of every Claude session. Skim it so you know what Claude already knows.
- [`CODING_STANDARDS.md`](./CODING_STANDARDS.md) — what we expect in PRs.
- [`ARCHITECTURE.md`](./ARCHITECTURE.md) — where things go and why.
- [`WORKFLOW.md`](./WORKFLOW.md) — the full git/PR flow (with the Notion task lifecycle).
- [`DATABASE.md`](./DATABASE.md) — Supabase migrations workflow.
- [`decisions/`](./decisions/) — Architectural Decision Records. Read [`0008-figma-first-frontend.md`](./decisions/0008-figma-first-frontend.md) before touching any UI.
- **API docs** at [venn-social.github.io/venn](https://venn-social.github.io/venn/documentation/venn/) — auto-generated DocC site from the doc comments in the Swift source. Updated on every push to `main`. Build locally with `make docs` and open the resulting `build/Venn.doccarchive` in Xcode.
