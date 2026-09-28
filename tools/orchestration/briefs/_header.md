# Crownless implementation brief

You are implementing ONE focused improvement in **Crownless**, a Godot 4.4 action-RPG. Your current
directory is a git worktree ("lane") on its own branch. Work only inside it.

## Environment rules (read carefully)
- This lane is a SPARSE worktree: `mobile/`, `art_src/` and docs assets are absent on purpose.
  `game/assets` is a HARDLINKED copy of the main worktree's assets (editing an asset file in place would
  edit the main copy too) and `game/.godot` is a JUNCTION into the main worktree. Never modify, delete,
  move or re-checkout anything under `game/assets` or `game/.godot`; never run `git clean`,
  `git sparse-checkout`, `git stash -u`, or `git checkout/restore` on those paths.
- Do not touch `mobile/` (the integrator syncs mobile later). Desktop `game/` is the source of truth.
- Do not add a new `class_name` (the shared import cache cannot register it from this lane); use
  `preload("res://...")` / `const X := preload(...)` instead.
- Read `CLAUDE.md` sections "Code layout", "Testing", "GDScript traps" before coding. Tuning numbers
  belong in `game/scripts/balance.gd` (no bare magic numbers). Match surrounding style.
- Keep the change surgical: fix the described problem well, do not refactor unrelated code, do not
  change unrelated behavior, preserve co-op/online behavior (host authority; tree pause no-ops online).

## Verification you must run
1. Compile gate (fast, run it after every edit batch):
   `./tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --script res://check_compile.gd`
   (from Git Bash) — must print `COMPILE OK`.
2. Add or extend a regression test that FAILS on the old behavior and PASSES on yours. Find the
   closest existing test module under `game/scripts/tests/` (or the autotest systems tier) and follow
   its pattern; snapshot + restore any shared state you touch; never assert on state an earlier section
   accumulated (control the preconditions).
3. Heavy runs (quick suite, shot rigs) are RAM-limited on this machine (a quick suite is ~3.7 GB) and
   MUST go through the machine-wide lock. Quick suite (the lock builds the command and checks the pass marker):
   `python C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder/build/qa/session-sept28/tools/glock.py --cwd <absolute lane path> --log <absolute lane path>/build_lane_logs/quick.log --suite quick`
   → trust only `[glock] SUITE VERDICT: PASS`. For a rig/module not covered by the quick tier, run it the way
   that module is normally run (check `shot.bat`, `tools/INDEX.md`, the module header) as
   `python .../glock.py --cwd <lane> --log <log> -- cmd.exe /d /c <absolute lane path>\shot.bat <rig> ...`
   (from Git Bash prefix the whole command with `MSYS_NO_PATHCONV=1`, otherwise `/d /c` is rewritten into
   paths and NOTHING runs — an exit 0 in a few seconds is not a pass). Always read the log for the real verdict.
   Do not run the full `test.bat`; the integrator runs it.
   The lock is shared by ~8 agents: queue AT MOST ONE heavy job at a time (wait for it before queueing the
   next), never run `preflight --strict` or the full suite in the lane (the integrator does), and if the
   queue is long, commit after the compile gate + your targeted check and say the quick run is pending.

## Finish
- Commit your work on the current lane branch with a clear, plain-English subject line (what the
  player gets). NO co-author / attribution trailers. Commit only your intended source/test files
  (never `build_lane_logs/`, never junction paths).
- Final message: what you changed (files + why), the regression test(s) and their results, the compile
  and quick-suite results, and anything you are unsure about or could not verify. Be honest about
  failures; do not claim a pass you did not see.

---
