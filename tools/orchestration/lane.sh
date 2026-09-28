#!/usr/bin/env bash
# Lightweight implementation lanes for parallel agents.
#   lane.sh create <name>   sparse worktree (no art/mobile), junctions game/assets + game/.godot to main,
#                           hardlinks the Godot exes. ~30 s, ~170 MB.
#   lane.sh reset <name>    hard-reset the lane branch to the main branch HEAD (discard lane work).
#   lane.sh diff <name>     print the lane's diff vs its base (committed + uncommitted).
#   lane.sh compile <name>  run the compile gate inside the lane.
set -euo pipefail
MAIN_POSIX="C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder"
MAIN_WIN='C:\Users\asali\Projects\MMO\.codex\worktrees\crownless-wayfinder'
BASE_BRANCH="codex/crownless-wayfinder"
cmd="$1"; name="$2"
L_POSIX="C:/Users/asali/Projects/MMO/.codex/worktrees/cw-lane-$name"
L_WIN="C:\\Users\\asali\\Projects\\MMO\\.codex\\worktrees\\cw-lane-$name"
case "$cmd" in
  create)
    cd "$MAIN_POSIX"
    git worktree add --no-checkout -b "sept28/lane-$name" "$L_POSIX" "$BASE_BRANCH"
    cd "$L_POSIX"
    git sparse-checkout init --no-cone
    printf '/*\n!/art_src/\n!/mobile/\n!/game/assets/\n!/marketing/\n!/archive/\n!/docs/\n!/build/\n' | git sparse-checkout set --no-cone --stdin
    git config sparse.expectFilesOutsideOfPatterns true
    git checkout "sept28/lane-$name" >/dev/null 2>&1
    # Assets = per-file HARDLINK farm, never a junction (a junction let a sparse reset wipe main's assets).
    python "$(dirname "$0")/farm.py" "$name"
    cmd.exe //c "mklink /J $L_WIN\\game\\.godot $MAIN_WIN\\game\\.godot" >/dev/null
    cmd.exe //c "mklink /H $L_WIN\\tools\\Godot_v4.4.1-stable_win64_console.exe $MAIN_WIN\\tools\\Godot_v4.4.1-stable_win64_console.exe" >/dev/null
    cmd.exe //c "mklink /H $L_WIN\\tools\\Godot_v4.4.1-stable_win64.exe $MAIN_WIN\\tools\\Godot_v4.4.1-stable_win64.exe" >/dev/null
    echo "lane $name ready at $L_POSIX"
    ;;
  reset)
    cd "$L_POSIX"
    git reset --hard "$BASE_BRANCH" >/dev/null
    # NEVER `git clean` here: game/assets and game/.godot are JUNCTIONS into the main worktree.
    git ls-files --others --exclude-standard -- . ':(exclude)game/assets' ':(exclude)game/.godot' \
      | while IFS= read -r f; do rm -f -- "$f"; done
    echo "lane $name reset to $(git rev-parse --short HEAD)"
    ;;
  diff)
    cd "$L_POSIX"
    git add -N . 2>/dev/null || true
    git diff "$BASE_BRANCH" -- . ':(exclude)game/assets' ':(exclude)game/.godot'
    ;;
  compile)
    cd "$L_POSIX"
    ./tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --script res://check_compile.gd 2>&1 | tail -15
    ;;
esac
