# Claude workflow improvements

Analysis written 2026-08-17, grounded in 7 days of session history (~100 sessions) and the feedback memory files. This is a working checklist. Do them when you have time; ranked by leverage.

## The five changes, ranked

### 1. Worktrees for parallel agents, not one shared tree
**Problem:** parallel agents in one `game/` tree cause commit races and misattribution (the 3-slice commit labeled as 2, mid-air staging collisions). `safe_commit.py` patches it per-incident but the class of bug survives.
**Fix:**
- [ ] Rule: worktree when two agents will touch overlapping files. Shared tree only for genuinely disjoint work.
- [ ] Weekly `git branch --no-merged main` sweep so worktree branches do not rot silently (see `agent-branch-hygiene` memory).
**Tradeoff:** worktree setup cost (`worktree-headless-setup` memory: hardlink Godot exes, `--import` once). Worth it only for overlapping work.

### 2. Memory consolidation pass  (DOING NOW, 2026-08-17)
**Problem:** most feedback memories carry 28-38 day staleness warnings. Stale memory is the exact trigger for the most expensive recurring leak (agent asserts wrong facts confidently). Documented 3x in `back-points-with-evidence`.
**Fix:**
- [ ] Run the consolidate-memory pass (in progress).
- [ ] Repeat monthly. Put it on the schedule (see #3).

### 3. Port the AlgoTrading scheduled-loop pattern to MMO maintenance
**Problem:** biggest untapped asymmetry. Trading research is automated on cron; all MMO QA is done by hand every session.
**Fix:** a nightly scheduled job that:
- [ ] runs the full suite (`test.bat`) and reports pass/fail
- [ ] reports mobile drift (`sync_mobile.py`)
- [ ] runs `preflight.bat`
- [ ] optionally runs the monthly memory consolidation
Catches regressions overnight instead of mid-session.

### 4. Turn gen-prompt lessons into an invokable template, not a doc I might recall
**Problem:** loose generation prompts are, in your words, "really what has been costing us tokens." `PIXELLAB_PROMPT_LESSONS.md` and the 8-frame labeled-gait technique exist but depend on the agent remembering to apply them.
**Fix:**
- [ ] Make a canned prompt header or skill: pose + palette/identity anchor + explicit negatives + screen-relative directions.
- [ ] For bipedal walks: default to the 8-frame labeled-gait row, not 2x2 sheets.

### 5. Front-load the source of truth in "what changed / where" prompts
**Problem:** agent re-derives or asserts from priors instead of checking the obvious source first. Cheapest leak to close.
**Fix:**
- [ ] Habit: open such prompts with "check `git show --stat <commit>` / the installed file first, then...". You already discovered this fix; make it reflex.

## Supporting context

### How you use Claude (from the data)
- ~24 hand-driven MMO sessions/week, one narrow topic each. Good hygiene.
- AlgoTrading runs ~60 scheduled loop sessions/week (Market loop ~30min, Research loop ~4h). Already automated.
- Career (3), Autonomy (1). Parallel agents in one tree, heavy generation load.

### What is already strong
- `CLAUDE.md` is a genuinely excellent operating manual.
- Traps are mechanized: `preflight.bat`, `safe_commit.py`, `sync_mobile.py`, `ShotRig`, `tools/INDEX.md`.
- Memory system captures rulings instead of re-litigating.
- Session-per-topic scope discipline.

### Recurring friction, ranked by cost
1. Agent asserts from stale memory instead of reading code (3 documented blowups).
2. Parallel-tree commit races and misattribution.
3. Loose gen prompts forcing re-rolls.
4. Presentation round-trips (fancy language, compressed table cells).
