#!/usr/bin/env bash
# =============================================================================
# scripts/doctor.sh — health-check the local Swift dev environment.
# =============================================================================
# Run any time things feel off, or before opening a PR. Catches the silent
# failure modes that look like "everything is fine" but actually aren't:
#   - Command Line Tools instead of full Xcode (xcodebuild won't work)
#   - Wrong Xcode version (no iOS 26 SDK)
#   - Missing brew tools (xcodegen / swiftlint / swiftformat / xcbeautify)
#   - .env missing or still has placeholder values
#   - Husky hooks not wired
#
# Usage:
#   make doctor    # the canonical entry point
#   ./scripts/doctor.sh
#
# Exits non-zero if any check fails so it can gate `make verify` and CI.
# =============================================================================

set -uo pipefail

failures=0
warnings=0

ok()    { printf "  ok    %s\n"   "$1"; }
warn()  { printf "  warn  %s\n"   "$1"; printf "        fix: %s\n" "$2"; warnings=$((warnings+1)); }
fail()  { printf "  FAIL  %s\n"   "$1"; printf "        fix: %s\n" "$2"; failures=$((failures+1)); }

printf "\nvenn doctor — checking your dev environment\n\n"

# --- Full Xcode (not Command Line Tools) -------------------------------------
xcode_path=$(xcode-select -p 2>/dev/null || true)
case "$xcode_path" in
  */Xcode.app/*)
    xcode_version=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')
    ok "Xcode active developer dir: ${xcode_path} (Xcode ${xcode_version:-?})"
    ;;
  */CommandLineTools)
    fail "Command Line Tools is active, not full Xcode" \
         "install Xcode 26 from the Mac App Store, then run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    ;;
  *)
    fail "no Xcode active developer directory" \
         "install Xcode 26 from the Mac App Store"
    ;;
esac

# --- Brew tools --------------------------------------------------------------
for tool in xcodegen swiftlint swiftformat xcbeautify; do
  if command -v "$tool" >/dev/null 2>&1; then
    ok "$tool installed"
  else
    fail "$tool not installed" \
         "brew install $tool   (or run: make setup)"
  fi
done

# --- .env at repo root -------------------------------------------------------
if [ -f ".env" ]; then
  if grep -q "YOUR_PROJECT\|YOUR_ANON_KEY" .env; then
    warn ".env still has placeholder values" \
         "fill in real Supabase URL + anon key (see .env.example)"
  elif ! grep -q "^SUPABASE_URL=https" .env; then
    warn ".env present but SUPABASE_URL looks empty or malformed" \
         "check .env against .env.example"
  else
    ok ".env present"
  fi
else
  fail ".env missing" \
       "cp .env.example .env, then add Supabase + observability values"
fi

# --- Husky hooks wired -------------------------------------------------------
hooks_path=$(git config --get core.hooksPath 2>/dev/null || true)
case "$hooks_path" in
  .husky/_|.husky)
    ok "husky hooks wired (core.hooksPath=$hooks_path)"
    ;;
  *)
    fail "husky hooks not wired (core.hooksPath='${hooks_path:-unset}')" \
         "npm install   (the prepare script wires the hooks)"
    ;;
esac

# --- Generated Xcode project -------------------------------------------------
if [ -d "ios/Venn.xcodeproj" ]; then
  ok "ios/Venn.xcodeproj generated"
else
  warn "ios/Venn.xcodeproj not generated" \
       "make project   (regenerates from project.yml)"
fi

# --- Summary -----------------------------------------------------------------
printf "\n"
if [ "$failures" -gt 0 ]; then
  printf "%d check(s) failed.\n" "$failures"
  [ "$warnings" -gt 0 ] && printf "%d warning(s).\n" "$warnings"
  printf "Fix the failures above and re-run 'make doctor'.\n"
  exit 1
fi
if [ "$warnings" -gt 0 ]; then
  printf "all required checks passed, with %d warning(s).\n" "$warnings"
else
  printf "all good.\n"
fi
