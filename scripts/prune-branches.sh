#!/usr/bin/env bash
# =============================================================================
# prune-branches.sh — delete local branches whose remote branch is gone.
# =============================================================================
# After a PR is squash-merged, GitHub deletes the remote branch but the local
# copy lingers. Because we squash-merge, `git branch -d` never sees those
# branches as "merged", so they pile up. This script finds local branches
# whose upstream has been deleted and removes them.
#
# Usage:
#   make prune-branches          # dry run — lists what would be deleted
#   make prune-branches-force    # actually delete
#
# Branches with no upstream at all (never pushed) are left alone — they may
# hold unpushed work.
# =============================================================================

set -euo pipefail

mode="${1:-dry-run}"

git fetch --prune --quiet

gone_branches=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads |
  awk '$2 == "[gone]" { print $1 }')

if [ -z "$gone_branches" ]; then
  echo "No stale branches — every local branch either tracks a live remote or was never pushed."
  exit 0
fi

if [ "$mode" = "delete" ]; then
  echo "Deleting local branches whose remote is gone:"
  echo "$gone_branches" | while IFS= read -r branch; do
    git branch -D "$branch"
  done
else
  echo "Local branches whose remote branch has been deleted (squash-merged PRs):"
  echo
  echo "$gone_branches" | sed 's/^/  /'
  echo
  echo "Dry run — nothing deleted. Run 'make prune-branches-force' to delete them."
fi
