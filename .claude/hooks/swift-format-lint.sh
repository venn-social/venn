#!/usr/bin/env sh
# PostToolUse hook (Edit|Write) — keeps Swift that Claude edits clean.
#
# Reads the hook JSON on stdin, extracts the edited file path, and for
# Swift files:
#   - SwiftFormat: formats the file in place (mirrors .husky/pre-commit).
#   - SwiftLint:   lints --strict; violations are surfaced back to Claude
#                  immediately (exit 2) so they're fixed now, not at commit.
#
# Non-Swift files and missing tools are skipped silently so the hook is a
# no-op for docs, JSON, and fresh clones that haven't run `make setup`.
#
# Disable any time via /hooks.

file=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)

# Only act on Swift source files that exist on disk.
case "$file" in
  *.swift) ;;
  *) exit 0 ;;
esac
[ -f "$file" ] || exit 0

# Format in place (best-effort — never block on a formatter hiccup).
if command -v swiftformat >/dev/null 2>&1; then
  swiftformat --quiet "$file" >/dev/null 2>&1 || true
fi

# Lint strict; surface violations back to the model as actionable feedback.
if command -v swiftlint >/dev/null 2>&1; then
  violations=$(swiftlint lint --strict --quiet "$file" 2>/dev/null || true)
  if [ -n "$violations" ]; then
    echo "SwiftLint violations in $file — fix before continuing:" >&2
    echo "$violations" >&2
    exit 2
  fi
fi

exit 0
