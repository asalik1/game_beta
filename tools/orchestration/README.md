# Multi-agent orchestration kit (Crownless, first used 2026-09-28)

How one orchestrator session ran ~20 improvement tasks in parallel on this box: Codex (and, while its
credit lasted, DeepSeek) implement in lightweight lane worktrees, Claude subagents review and fix, and the
orchestrator integrates, gates and commits. The scripts here are the exact ones used; paths inside them
point at `C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder` and `build/qa/session-sept28/`.
Adjust `MAIN`/`Q` before reusing them elsewhere.

## Pipeline

1. **Ideate** (read-only): Claude scouts (Workflow, 4 lenses) + `cx_agent.py --readonly` +
   `ds_agent.py --readonly`. Different models find different things. Claude scouts found the deepest
   cross-product bugs, Codex found real combat math bugs cheaply. A second, narrowed Codex round
   ("combat/progression only, exclude what landed today") refills the backlog at no Claude cost.
2. **Brief**: `briefs/_header.md` (lane rules, compile gate, lock, regression test, commit on lane,
   honest report) + a task body. `mkbrief.py <id> "<title>" <scout idx...>` builds it from scout JSON.
3. **Implement**: `cx_agent.py <lane> <prompt> <out>` from the orchestrator's own background shell
   (always `wait` for it, or no completion notice arrives). One task per lane.
4. **Review + fix**: `review_fix.js` (3 read-only lenses → fixer → independent verifier, up to 2 rounds)
   or `review_lite.js` (1 combined reviewer → fixer → verifier; about half the tokens) via the Workflow
   tool with `scriptPath` + args `{task,title,lane,branch,run}`. `fix_verify.js` finishes an interrupted
   run from saved findings (`args.findings`) or a saved fixer result (`args.fix`).
5. **Integrate**: `integrate.sh <lane> "<subject>" "<body>"` squash-applies merge-base..lane onto the
   main branch with `git apply --3way --index`, generates missing `.uid`s, and makes a path-scoped
   commit. Then run the quick suite on main right away, and batch the full suite + mobile sync
   (`tools/sync_mobile.py --apply --paths ...`) + `mobile_gate.py` every 3-4 tasks.

## Lanes (`lane.sh create|reset|diff|compile <name>`)
- A full checkout is ~15 GB, so a lane is a SPARSE worktree without art_src/mobile/game/assets/docs
  (~170 MB, ~30 s), with `sparse.expectFilesOutsideOfPatterns=true` (without it `git status` takes 90+ s).
- `game/assets` = per-file HARDLINK farm (`farm.py`, ~40 s). `game/.godot` = junction (untracked cache).
  NEVER junction a tracked directory into a sparse worktree: on 2026-09-28 a `git reset --hard` in a
  lane whose skip-worktree bits had been cleared deleted all 20,267 main assets through the junction.
  They were recovered with `git restore`, plus `-c core.autocrlf=false` for the .import files.
- No new `class_name` in lanes (the shared class cache can't register it).

## The heavy-run lock (`glock.py`)
- A headless quick suite is ~3.7 GB RSS on this ~10 GB box, so only ONE heavy Godot run at a time.
  `glock.py [--priority] --cwd <dir> --log <f> --suite quick|full|preflight` builds the .bat command
  itself and fails unless the pass marker is present. Other rigs: `-- cmd.exe /d /c <abs>\shot.bat ...`
  with `MSYS_NO_PATHCONV=1` (Git Bash otherwise rewrites `/d /c` and NOTHING runs: exit 0 in 0 s).
- FIFO tickets in `%TEMP%\crownless_glock_queue`; only each cwd's oldest ticket is eligible
  (per-lane round-robin); `--priority` for integration gates.
- The lock, not the implementers, is the bottleneck (~20 heavy runs/hour). Keep at most about 7 tasks in
  flight, and one queued heavy job per agent.

## Providers
- `cx_agent.py`: `codex exec --json -o <abs path>` (a relative `-o` breaks under `-C`), prompt on stdin,
  `--dangerously-bypass-approvals-and-sandbox` for lanes, `-s read-only` for ideation. Codex ends its
  turn rather than wait long on the lock, so reviews must accept uncommitted lane work.
- `ds_agent.py`: DeepSeek as a Claude Code agent via `ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic`
  + `ANTHROPIC_API_KEY` from HKCU\Environment. Scrub every inherited `CLAUDE*`/`ANTHROPIC*` var first,
  or the child sends the host session's token (401). Check `GET /user/balance` first: agentic runs
  resend the whole context each turn and drained the balance in 3 runs.

## Budget notes
- One full review_fix ≈ 0.75-1.0M Claude subagent tokens; review_lite ≈ 0.45-0.65M. About 8-9 full reviews
  used up one Claude usage window, and the limit killed in-flight fix/verify agents. Never edit a
  workflow script while runs of it are in flight (a resume then re-runs everything).
- Verifier rejections leading to a second fix round caught real regressions: a 7-13 ms/frame co-op cost,
  a non-modal touch editor, and dedicated arenas that never re-armed.
