"""Replace a lane's game/assets JUNCTION with a HARDLINK FARM of the main worktree's assets.

Why: a junction shares the directory itself — any git sparse "reapply" or recursive delete in the lane
deletes the MAIN worktree's files (happened 2026-09-28 09:14 UTC: all 20,267 assets wiped by
`git reset --hard` in a lane whose skip-worktree bits had been cleared). With per-file hardlinks, a
delete in the lane only removes the lane's link; main's file survives. Git rewrites files by
unlink+create, which also breaks the link instead of editing main's copy.

usage: python farm.py <lane-name>   (run under glock so no heavy Godot run is using the lane)
"""
import os, subprocess, sys, time
from pathlib import Path

MAIN = Path(r"C:\Users\asali\Projects\MMO\.codex\worktrees\crownless-wayfinder\game\assets")
lane = Path(rf"C:\Users\asali\Projects\MMO\.codex\worktrees\cw-lane-{sys.argv[1]}\game\assets")


def count(p):
    return sum(len(f) for _, _, f in os.walk(p))


before = count(MAIN)
t0 = time.time()
if lane.exists() or os.path.lexists(lane):
    if os.path.isjunction(lane) or lane.is_symlink():
        # rmdir WITHOUT /s removes only the reparse point, never the target's contents.
        subprocess.run(["cmd.exe", "/d", "/c", "rmdir", str(lane)], check=True)
    else:
        sys.exit(f"{lane} is a real directory, not a junction - refusing to touch it")
assert count(MAIN) == before, "MAIN ASSET COUNT CHANGED - STOP"
n = 0
for root, dirs, files in os.walk(MAIN):
    rel = Path(root).relative_to(MAIN)
    dst = lane / rel
    dst.mkdir(parents=True, exist_ok=True)
    for f in files:
        os.link(Path(root) / f, dst / f)
        n += 1
after = count(MAIN)
print(f"farm {sys.argv[1]}: {n} hardlinks in {time.time()-t0:.0f}s; main files {before} -> {after}")
assert after == before
