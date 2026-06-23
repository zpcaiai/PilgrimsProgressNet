#!/usr/bin/env bash
# Fix the rejected GitHub push.
#
# GitHub rejects any blob > 100 MB. A 224 MB installer
#   assets/scenes/QoderWork-arm64.dmg
# was committed in b9cc05a and deleted in 85167d1 — but the blob still lives
# INSIDE those (unpushed) commits, so the whole push is rejected.
#
# This script strips that blob out of every commit on `main`, ignores future
# .dmg files, repacks, and then prints the push command for you to run.
# It does NOT push on its own — the force-push is your deliberate last step.
#
# Safe for a solo repo (you are the only one on `main`). Run once:
#   bash tools/fix_git_dmg.sh
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Repo: $(pwd)"

BIG="assets/scenes/QoderWork-arm64.dmg"

# 0) Clear any stale lock left by other tooling.
rm -f .git/index.lock .git/HEAD.lock

# 1) Sanity: on main, history present.
git checkout main
git rev-parse --verify HEAD >/dev/null

# 2) Purge the blob from all history on this branch.
echo "→ Rewriting history to remove $BIG ..."
export FILTER_BRANCH_SQUELCH_WARNING=1
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch '$BIG'" \
  --prune-empty HEAD

# 3) Never track .dmg installers again.
grep -qxF '*.dmg' .gitignore 2>/dev/null || \
  printf '\n# large macOS installers — never commit\n*.dmg\n' >> .gitignore
git add .gitignore
git commit -m "chore: stop tracking .dmg installers" || true

# 4) Drop the rewrite backup and repack so the blob is gone locally too.
rm -rf .git/refs/original
git reflog expire --expire=now --all || true
git gc --prune=now || true

# 5) Verify nothing over 100 MB remains reachable.
echo "→ Any remaining blobs > 100 MB (should be none):"
git rev-list --objects --all \
  | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' 2>/dev/null \
  | awk '$1=="blob" && $2>104857600 {printf "   %d MB  %s\n", $2/1048576, $3}' \
  | sort -rn | head || true

echo
echo "============================================================"
echo "  Local history cleaned. Now push the rewritten branch:"
echo
echo "      git push --force-with-lease origin main"
echo
echo "  (The game's Vercel deploy is separate and does NOT need"
echo "   this push — run  bash tools/deploy_vercel.sh  any time.)"
echo "============================================================"
