#!/usr/bin/env bash
# integrate.sh <lane-name> "<commit subject>" ["<commit body>"]
# Squash-cherry-picks the lane's commits (merge-base..lane branch) onto the main worktree branch as ONE
# commit, touching only the lane's changed paths (the 46 unrelated dirty/untracked files stay untouched).
# New .gd scripts get their .uid via a headless --import in the main worktree. No mobile sync here.
set -euo pipefail
M="C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder"
lane="$1"; subject="$2"; body="${3:-}"
LB="sept28/lane-$lane"
cd "$M"
test "$(git branch --show-current)" = "codex/crownless-wayfinder"
base=$(git merge-base HEAD "$LB")
files=$(git diff --name-only "$base" "$LB")
echo "== integrating $LB ($base..$LB)"; echo "$files"
if [ -n "$(git diff --cached --name-only)" ]; then echo "INDEX NOT EMPTY - abort"; exit 2; fi
git diff "$base" "$LB" --binary > "build/qa/session-sept28/runs/integrate-$lane.patch"
if ! git apply --3way --index "build/qa/session-sept28/runs/integrate-$lane.patch"; then
  echo "APPLY CONFLICT - resolve manually"; git status --short | grep -v '^??' | head -20; exit 3
fi
new_gd=$(git diff --cached --name-only --diff-filter=A | grep -E '^game/.*\.gd$' | while read f; do test -f "$f.uid" || echo "$f"; done || true)
if [ -n "$new_gd" ]; then
  echo "== new scripts -> --import for .uid"
  python build/qa/session-sept28/tools/glock.py --priority --cwd "$M" --log "build/qa/session-sept28/runs/import-$lane.log" -- \
    "$M/tools/Godot_v4.4.1-stable_win64_console.exe" --headless --import --quit --path game >/dev/null 2>&1 || true
  for f in $new_gd; do test -f "$f.uid" && git add -- "$f.uid" && echo "uid: $f.uid"; done
fi
paths=$(git diff --cached --name-only)
msg="$subject"; [ -n "$body" ] && msg="$subject

$body"
git commit -q -m "$msg" -- $paths
git log --oneline -1
