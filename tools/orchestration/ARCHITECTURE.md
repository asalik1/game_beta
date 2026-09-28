# Crownless orchestration architecture (living document)

Maintained by each session's root orchestrator. The owner reviews it. Created 2026-09-28 from the v1 retrospective and five v2 architect proposals.

## 1. Purpose and how to use this doc

- **What it covers.** How the multi-agent development workflow is built: who implements, reviews, gates and integrates; which model and effort run each step; the lock and budget policy; and a log of what each architecture experiment showed.
- **Before orchestrating.** Read §3-§7. They are the operating rules. §9 lists ideas that were already rejected; do not propose them again without new evidence.
- **After every session, append:**
  1. Rows in §8 for every experiment you ran, plus any new observation that has numbers.
  2. A scorecard in the §2 format if the architecture changed.
  3. Edits to §3-§7, but only when a §8 row justifies them. Cite the row.
  4. Any newly rejected ideas in §9.
- **Citations.**
  - T01-T24 are task ids.
  - I1-I8 are the incidents in `tools/orchestration/evidence/2026-09-28-evidence.md`.
  - Times are UTC, from `tools/orchestration/evidence/2026-09-28-notes.md`.
  - "Re-measured" means a number the v2 architects derived from transcripts, workflow journals, Codex events and gate logs on 2026-09-28. Where they disagree, this doc says so.
- **Units.**
  - **$-eq** is the API list-price equivalent computed from usage fields. It is the only unit that tracked the usage limit (§4).
  - **Lock-s** is seconds of occupancy of the single heavy-run slot.
  - **Transcript tokens** means input + cache-write + output tokens, with cache reads excluded.

## 2. v1 as run on 2026-09-28

**How v1 ran.**
- **Root.** One Opus 5.5 root session (07:00 to about 18:40) wrote briefs and launched Codex implementers (gpt-6-astra, effort high) from its own background shell into sparse lane worktrees. Assets were hardlink farms after I1.
- **Review.** Each lane got one Workflow: `review_fix.js` (3 read-only lenses, then fixer, then verifier, up to 2 rounds) or, from 12:40, `review_lite.js` (1 combined lens, then fixer, then verifier).
- **Integration.** Accepted lanes were squash-applied with `integrate.sh`. Full, mobile and preflight gates were batched on main.
- **Models.** Every Claude subagent ran Opus 5.5 at xhigh, because no script set model or effort.
- **Lock.** All heavy Godot runs went through one machine-wide slot, `glock` (a quick run is about 3.7 GB RSS and takes 2-3 min).
- **Outcome.** 22 features and 2 merges were integrated, about 2.1 accepted tasks per hour. Every review found a real issue. There was one usage-limit outage (I3), one asset-deletion incident (I1) and one cross-lane regression (I6).

| Dimension | What happened | Evidence | Verdict |
|---|---|---|---|
| Implementation (Codex, high) | 24/24 tasks delivered, self-tested, honest reports; kept working through the Claude limit | 13-60 min each; T17, T19 and T20 ended or timed out in the lock queue with work uncommitted | Worked |
| Review catch rate | At least 1 real issue in every lane; about 38 majors in 23 reviews (re-measured); fixers applied about 150 findings and rejected about 14 (about 91% precision) | T01 bag potion, T04 non-modal editor, T05 victory under the death card, T09 pad B, T11 arena never re-armed | Worked |
| Independent verifier | 2 real round-1 rejections; 25-26 quick re-runs on trees the fixer had already passed changed 0 verdicts | T02 7-13 ms/frame cut to about 2 ms; T13 tall-canvas feed collapse | Mixed: judgment worked, gate re-runs were wasted |
| Heavy-run lock | Ran near saturation (utilization about 0.85-0.9 by Pollaczek-Khinchine); queue of 8-17 | Codex waits: mean 550 s, p50 397, p90 1,344; hourly mean 1,143-1,525 s from 13:00 to 15:00; about 1,100-1,300 lock-s per task; 11 of 107 Codex attempts never acquired | Failed |
| Throughput | About 2.1 tasks/h against a lock ceiling of about 2.7; roughly 7 tasks in flight only added waiting | T08 and T13 took 3.8 h of review wall; median dispatch-to-accept about 116 min | Mixed |
| Claude budget | Limit hit at about 10:30, about 1.5 h lost; the T02, T05 and T09 fix/verify agents were killed | 135 idle gaps over 5 min in fixers and verifiers produced 19.5M cache-write tokens (about $97 of $431 subagent $-eq); review cost follows wall time (r²=0.93, about 15k tokens/min) | Failed |
| Lane isolation | A junction deleted all 20,267 main assets; the hardlink farm fixed it | I1; 0 incidents afterwards; 7 clean teardowns | Worked after the fix |
| Integration | 21/24 applies were clean; 1 cross-lane regression; 2 conflicts; UU files left in main once | I6: T17 verified on stale base 4c6bd52, main red about 50 min (15:54-16:40); I7: T08, T13 | Mixed |
| Verdict integrity | A false pass (exit 0 in 0 s) and a false FAIL (UTF-16 log) | I5; 12:40 mobile gate | Worked after fix (suites only; rigs are still unguarded) |
| Root orchestration | Never implemented, but made 6 or more mechanical errors, and state lived only in its context | I8; 393 turns, 272 Bash calls (136 of them state reads); context grew from 67k to 661k | Mixed |
| Ideation | Claude scouts went deepest; Codex was cheap; DeepSeek drained its balance | 4 scouts: 1.33M, 16 min, 29 proposals; Codex round 2: 7 min, 6/6 bugs confirmed; I2 | Worked (DeepSeek failed) |
| Observability | No lock ledger; the Workflow token metric is not the limit meter; stats had to be rebuilt after the fact | Workflow "tokens" equal the sum of final contexts (T04 exactly 0.79M); 14.5M transcript tokens hit the limit from 07:00 to 10:30, but 23M did not from 12:00 to 17:00 | Failed |

## 3. Recommended v2 architecture

v2 is a pyramid, but its middle layer is code. Five rules follow from the §2 evidence:

1. **The root is the only LLM that decides across lanes.** Do not use LLM lane managers.
   - An agent that waits rebuilds 135-150k tokens after every gap longer than the 5-minute subagent cache TTL.
   - Root turns are cheap: 1.17M non-cached tokens for the whole v1 day.
2. **No Opus context waits on the lock.** Heavy runs are executed by scripts, driven by a Haiku runner. Judgment agents read receipts.
3. **Verdicts come from code** (pass markers, exit codes, receipts), never from an agent's prose.
4. **Test the tree that will land.** Lanes sync with main before review and again before the final gate.
5. **Freeze the kit during a session.** A change goes into a new versioned file written by Codex. The root never implements, and that includes kit code.

```
L0 ROOT            Opus 5.5 high. Owns: backlog, brief approval, risk tier, admission, integrate
                   go/no-go, incidents, kit-change specs, this doc. Reads board.py digest per event.
                        |  launches                                  ^  1 notification per lane/integration
L1 CONTROL PLANE   code, 0 Claude tokens ("managers")
                   dispatcher.py     approved-brief queue -> cx_agent.py on free lanes (always waits)
                   lane workflow v2  one per lane: seal+lint+sync -> review || G0 -> fix -> sync -> G1 || judge -> AND
                   integrate_gate.sh merge-tree check -> apply -> train quick (P0) -> revert on FAIL -> batch gates
                   board.py          derived state from receipts, journals, glock ledger, git
                        |
L2 WORKERS         Codex astra     implement, in-lane merges, toolsmith, ideation, break-it review (P6)
                   Opus 5.5        review lenses, major fixer, judge
                   Sonnet 5        minor-only fixer, follow-up briefs, shadow lenses (P5)
                   Haiku 4.5       gate runner (G0/G1), clean lane sync, failure-log triage, ledger summary
                   Fable 5.1       triggered adjudicator only
SHARED SERVICES    glock v2        1 exclusive heavy slot; P0-P3 classes; ledger; PASS receipts by tree hash
                   git             main codex/crownless-wayfinder; lanes sept<date>/lane-*; squash integration
```

**Lane workflow v2** (new files: `review_lite_v2.js`, `review_fix_v2.js`, `fix_verify_v2.js`)

| # | Step | Runs on | Lock | Output |
|---|---|---|---|---|
| 0 | Seal the lane, lint, and sync with main if `merge-tree` is clean (before launch) | cx_agent wrapper, `lint_lane.py`, `lane.sh sync` | none | WIP commit, `lane_state.json`, lint facts, conflict list (a conflict goes to Codex medium in the lane) |
| 1 | Review lenses run in parallel with G0 (quick suite on the implementer's HEAD) | Opus lenses; Haiku runner | G0 at P2 | FINDINGS; G0 receipt handed to the fixer |
| 2 | Fix | Opus 5.5 if any blocker or major, otherwise Sonnet 5 | compile gate plus at most 1 targeted rig, P2 | commits; `FIX.rigs` (the runs G1 must do) |
| 3 | Re-sync if main moved | Haiku runs `lane.sh sync` (exit 3 on conflict stops the lane as needs_merge) | none | merge commit |
| 4 | G1 gate runs in parallel with the judge | Haiku runs `gates.py`: compile unlocked, then one P1 bundle (listed rigs, then quick, fail-fast). The Opus judge reads the diff, brief, fixer commits, lint facts and receipts | P1; judge makes at most 1 probe | `gates.json`; VERDICT |
| 5 | Accept = judge.accept AND every G1 receipt PASS on the synced HEAD AND a clean lane | JS, deterministic | none | result plus a defect-ledger row |
| 6 | On reject: Opus fixer round 2, then steps 3-5 again. A round-2 reject or a §6 trigger goes to the Fable adjudicator | Opus / Fable | as above | final verdict |

**Durable state.** Every file is derived or append-only, so an agent dying mid-update cannot corrupt state.

| File | Written by | Holds |
|---|---|---|
| `build/qa/<session>/decisions.json` | root (by hand, small) | priority, risk tier, review mode, holds, kit version, workflow run ids |
| `runs/*/receipt.json`, `events.jsonl` | cx_agent.py | Codex rc, timed_out, final message |
| `lanes/<lane>/lane_state.json` | seal wrapper | HEAD sha, dirty flag, WIP reason, PASS receipt for HEAD |
| `%TEMP%/crownless_glock_ledger.jsonl` | glock v2 | role, task, lane, job, tree key, enqueue/acquire/release times, wait, service, verdict, peak working set |
| `gates/receipts/<treekey>-<job>.json` | glock v2 | PASS receipts, the cache source |
| Workflow `journal.jsonl` | Workflow runtime | findings, fix, verdict, per-agent usage |
| `build/qa/<session>/defect_ledger.jsonl` | root via `wfres.py` | one row per task: tier, model/effort per role, majors per lens, duplicates, applied/rejected, rounds, gate results, escapes, $-eq, wall time |
| `build/qa/<session>/ORCHESTRATOR_NOTES.md` (copied to `tools/orchestration/evidence/` at close) | root | narrative log and rules that bite |
| this doc | root at session close | architecture, experiments, decisions |

## 4. Model and effort tiering

Est. tokens are transcript tokens per run, from the re-measured v1 per-role totals once lock-wait rebuilds are removed.

| Step | Model | Effort | Why (evidence) | Est. tokens/run |
|---|---|---|---|---|
| Root orchestrator | Opus 5.5 | high | The judgment layer, and only about 8% of v1 spend. Its v1 errors were mechanical (I8), which is fixed by scripts and the board, not a bigger model | about 1.2M/day; roll over at 300k context |
| Ideation, narrowed domain rounds (2-3) | Codex astra, read-only | xhigh | 7-8 min per round, 6/6 combat bugs confirmed, 0 Claude tokens | 0 Claude |
| Ideation scouts (crossproduct-hunt, player-experience only) | Opus 5.5 | xhigh | The deepest cross-product bugs (touch revive in co-op, HUD during the death beat). Codex covers core bugs, so bug-hunt-core and open-issues are dropped | about 0.3M each |
| Briefs | `mkbrief.py`; follow-up briefs from verifier JSON on Sonnet 5 | medium | Structured input into prose (T16, T20, T21, T22 came from reviewer notes) | 0 / about 50k |
| Implementation, default | Codex astra | high | 24/24 tasks in 13-60 min, separate budget | 0 Claude |
| Implementation, small (<150 lines) and in-lane merges | Codex astra | medium | T22: 60 lines in 12 min, 1 finding. T08m took 12 min, T13m 6-7 min, both clean | 0 Claude |
| Kit changes (toolsmith) | Codex astra | medium | The root never implements; I3 and I8 came from live kit edits | 0 Claude |
| Seal, lint, merge-tree, markers, integrate, ledgers | scripts | none | I5, the 12:40 false FAIL and I7 were parsing or process bugs | 0 |
| Gate runner (G0/G1) and clean lane sync | Haiku 4.5 (a Bash-only agent type if P1 shows a smaller baseline) | low | Mechanical; the receipt is the trust anchor. A rebuild costs about 60k Haiku tokens instead of 135-150k Opus | 0.1-0.3M Haiku per lane |
| R2 lenses (logic/state, player surfaces, tests) | Opus 5.5 | xhigh | Headline majors came from all three lenses. Lenses were 22% of v1 tokens and never waited | about 0.18M each |
| R1 combined lens | Opus 5.5 | xhigh | Lite caught the T11, T16, T17 and T21 majors | 0.2-0.3M |
| Fixer, any blocker or major | Opus 5.5 | xhigh | Real engineering: T02 round-2 16k-layout equivalence probe, T21 PvP pen fix, T09 finishing interrupted work | about 0.25M (v1 about 0.67M, mostly waiting) |
| Fixer, minor-only | Sonnet 5 | high | About 20-25% of tasks (T10, T14, T15, T18, T24), all accepted in round 1. The Opus judge still gates | about 0.15M |
| Judge (verifier) | Opus 5.5 | xhigh | Both rejections (T02, T13) came from reading and probes, never from gate re-runs | 0.15-0.25M (v1 about 0.41M) |
| Adjudicator (§6 triggers only) | Fable 5.1 | high | Expected on about 10% of tasks; hard calls; 45-min cap | about 0.2M ($4-5) |
| Integration-regression fix | Opus 5.5 via `fix_verify_v2.js` | xhigh | T17×T16 needed 2 agents and 0.27M. Escalate to Fable only if it fails | about 0.3M |
| Failure-log triage; session ledger summary | Haiku 4.5 | low | Returns at most 15 lines, keeping raw logs out of the root (about 117k chars of tails in v1) | about 50k |
| DeepSeek | off | none | No credit (I2) | n/a |

**Per-window budget math.**
- **Calibration.** The limit hit at about $190 $-eq per 5-hour window: $177.5 subagent plus $12.6 root, 07:00-10:20.
  - The Workflow token figure (about 8-9M) undercounts cache reads and cold rewrites, so do not budget in it.
  - Recalibrate at every limit hit, because other sessions may share the account.
- **v1 per-task cost.**
  - Full review: $21.7 ($7.2 review + $14.5 fix/verify).
  - Lite review: $13.0 ($2.9 + $10.1).
- **v2 per-task cost.** v2 keeps the lenses unchanged. Removing waits cuts fix plus judge to about $6.6 for R2 and $4.6 for R1. Add about $0.5 for Haiku and about $0.5 of amortized Fable.
- **Lock ceiling.** Computed at 60% utilization, the target that keeps mean waits at about 2-3 min.

| | v1 | v2 structural | v2 if P5 passes |
|---|---|---|---|
| $-eq per full/R2 task | 21.7 | about 14.8 | about 12.6 |
| $-eq per lite/R1 task | 13.0 | about 8.5 | about 7.6 |
| Tasks per window, 50/50 mix, 100% of window | about 11 (observed: 8-9 full) | about 16 | about 19 |
| Same, at the 85% admission cap | about 9 | about 14 | about 16 |
| Ideation per session / root per day | $32.5 / $38 | about $16 / $20-25 | same |
| Lock-s per task | about 1,200 | about 775 | about 600 with the module runner |
| Lock ceiling at 60% utilization (tasks/h, per 5 h) | 1.8 (9) | 2.8 (14) | 3.6 (18) |

Under v2 the Claude window and the lock bind at roughly the same point (about 14 tasks per 5 hours). That balance is intended; growing either one alone is wasted.

## 5. Throughput and lock policy

1. **Only Godot goes through glock.** Suites, rigs, modules, `--import` and `mobile_gate.py` use the lock. farm.py, git, sync_mobile copies, the PowerShell fixture tests, log parsing and reviews run unlocked. (At 09:50 a 38-second farm job waited more than 20 min.) The compile gate stays unlocked and runs before anything is enqueued.
2. **Priority classes.**
   - The classes are P0 integrate/maintenance, P1 G1 gate and judge probe, P2 G0 gate and fixer rig, P3 implementer.
   - Within a class, order is FIFO with per-lane round-robin (kept from v1).
   - A P3 ticket is promoted to P2 after waiting 20 min.
   - One outstanding ticket per lane: a second is rejected, and a new ticket for the same lane and job supersedes an unstarted one. (T20 queued 6 jobs; the queue reached 15.)
3. **Who runs what.**
   - Implementer: compile, then one P3 bundle of its targeted module or rig.
     - Fail-before is proven with that module against copied-aside old code.
     - No quick runs, no baseline or "before" suites, no full or preflight; glock refuses full and preflight below P0.
     - In v1, 13 baseline runs and 5 lane preflights cost 2,095 lock-s, and T17, T19 and T20 stalled in the queue.
   - Fixer: compile plus at most 1 targeted rig.
   - G0: one quick run.
   - G1: one fail-fast bundle.
   - Judge: at most 1 probe and never a quick run (25-26 verifier re-runs in v1 changed 0 verdicts).
4. **Bundling.** One acquisition runs the listed jobs cheapest first and stops at the first failure. (T13's Codex made 7 separate acquisitions, each waiting 722-1,575 s.)
5. **Bounded waiting.** `glock --wait-max 270` returns "queued, position N" before the 5-minute cache TTL, and the agent calls again. Until that exists, the Haiku runner polls in chunks of 4 min or less. In v1, 132 of the 135 costly gaps followed a glock wait.
6. **Dedupe by receipt.**
   - The key is job + normalized args + a tree hash of suite-relevant paths, including uncommitted changes (temp index, `git add -A -- game tools *.bat *.ps1`, excluding `game/.godot` and `build_lane_logs`, then `write-tree`) + the Godot exe hash.
   - FAIL is never cached, and `--no-cache` forces a run.
   - The cache ships in shadow mode until P3 passes.
   - Expected hits: resumes after a limit, round 2 on an unchanged tree, G1 when the fixer changed nothing, and the train quick when main has not moved since the lane synced.
7. **Admission control.** The root checks the board digest before each dispatch and launches a new implementer only if all four hold:
   - at most 3 lanes are past implementation;
   - at most 5 lanes exist in total;
   - the glock queue is at most 2 deep and 30-minute utilization is under 65%;
   - projected window $-eq plus this task's estimate is under 85% of the calibrated window.

   Why these limits:
   - Little's law: about 3 tasks/h × about 1.3 h dispatch-to-accept ≈ 4 in flight.
   - At utilization 0.6 with about 150 s of service, the mean wait is about 2-3 min. At 0.85-0.9 the same formula reproduces v1's 550 s.

   When a condition fails, put the brief in the dispatcher queue instead of launching it. Read-only Codex ideation is never capped. During a Claude limit, the dispatcher may keep up to 2 extra lanes implementing so reviews can start at the reset (v1 had no Codex runs from 09:54 to 12:04).
8. **Integration** (`integrate_gate.sh`, one background call per train).
   1. Check with `git merge-tree --write-tree --name-only HEAD <lane>` and `git apply --3way --check`. On a conflict, leave main untouched and send a Codex medium in-lane merge brief.
   2. Apply, import `.uid`s at P0, and make a path-scoped commit.
   3. **Train**: land at most 3 lanes, then run one P0 quick, skipped on a cached PASS. On FAIL, revert the train's commits and re-land the lanes one at a time with a quick after each. The failing lane goes to `fix_verify_v2` with its log.
   4. Every 4th integrated lane, or when the lock has idled 2 min or more with 2+ lanes landed since the last full: run full + mobile sync/gate as one P0 bundle in place of that train's quick.
   5. Run `preflight --strict` only at session end, or when `tools/`, rigs, `INDEX.md` or import paths change. It passed 2/2 in v1 with no catch.
9. **Quick-tier budget.** A Codex infra task adds three things:
   - a targeted module runner (`--module=res://scripts/tests/<m>.gd`);
   - per-section timings in the quick log;
   - a preflight check that fails if the quick tier exceeds 150 s.

   New regression tests are standalone `run(t)` modules and join the quick tier only if cheap. Evidence: quick grew from 164 to 182 sections and its service time from about 105 s to 130-145 s, which taxes every role.

## 6. Quality policy

**Risk routing.** The root tags a tier on each brief. A diff script may raise the tier and never lowers it.

| Tier | Criteria | Review | Fixer | Judge |
|---|---|---|---|---|
| R2 | Any of: co-op/online/net authority; per-frame `_process`/`_draw` paths; input/overlay gating (`input_overlay_up`, pause); touch/pad/mobile canvases; death/victory/story beats; the shared `autotest.gd` harness; a multi-part brief; more than 8 files or more than 400 changed lines | 3 lenses, each naming what the others own: (a) logic/state/lifecycle/authority; (b) player surfaces (touch, pad, tall/wide canvas, online, modal interruptions, copy); (c) tests (fails on base? wired into a tier? what is uncovered?) | Opus if any blocker or major, else Sonnet | Opus xhigh plus the adversarial checklist |
| R1 | Everything else | 1 combined lens (rule checks moved to lint) | same rule | Opus xhigh |

**Why these tiers.**
- Both rejections (T02, T13), I6 (T17 input gating × T16 overlay) and every headline major (T01, T04, T05, T07, T09) sat on R2 surfaces.
- All 5 reviews with no major (T10, T14, T15, T18, T24) were narrow tasks.
- T13 ran as lite and needed a second round; under this table it would be R2.
- In v1, 4 of 11 full reviews spent a lens duplicating another lens's major (T04, T07, T12, T02), so the lenses are refocused to reduce overlap.

**Guards that must run.** All are mechanical, and none is left to LLM judgment.

| Guard | When | Tool | On failure |
|---|---|---|---|
| Seal | The implementer exits, including on timeout | cx_agent wrapper | WIP commit "implementer stopped (<reason>)"; `lane_state.json`. Removes the process majors seen on T17, T19 and T20 |
| Brief-item ledger | Implementer's final report | header rule plus lint | Every item is DONE, SKIPPED (with file:line) or PARTIAL. Each lens re-checks every SKIPPED premise, and an unverified skip counts as a major (T21) |
| Lint facts | Before review | `lint_lane.py` | Injected as "already checked": em dashes in new strings, new `class_name`, staged `build_lane_logs`/assets/`.godot`, a `.gd` without a `.uid`, an unwired test module, bare numbers outside `balance.gd` (warning only) |
| merge-tree check | Before review, before sync, before integration | git | needs_merge goes to Codex medium in the lane; main is never touched (I7) |
| Marker and minimum runtime | Every heavy run, rigs included | glock v2 (`--suite`, `--expect <marker>`) | FAIL; an exit 0 in under about 10 s is never a pass (I5) |
| BOM-aware decode | Every log read | glock v2, gates.py | Prevents false FAILs like the 12:40 one |
| Asset canary | Before each acquisition | glock v2 (count of main `game/assets` or a sentinel) | Refuse the run and write `%TEMP%/crownless_ALERT` (I1 was found only from prose in T08's report) |
| Hard gates | End of the lane workflow | JS AND | accept=false on a sync conflict, a G1 FAIL or uncommitted source. The LLM cannot downgrade these to "minor" (T08's verifier did) |
| `anomalies` field | FIX and VERDICT schemas | schema | Environment problems appear in the notification, not buried in risk_notes |

**What the judge must prove**, citing evidence for each item:
1. The final diff against the merge-base with current main (after sync) does each brief item, or correctly skips it.
2. No blocker or major remains, including regressions the fixer introduced. The judge diffs the fixer's commits against the implementer's head: T02's perf cost came from the round-1 fix, and T13's feed collapse from a chat ceiling the fixer added.
3. The new tests would fail on base.
4. G1 receipts show PASS for the exact synced HEAD (the script re-checks this; the judge cites receipt paths).
5. R2 only, logged item by item:
   - **Mutation check:** revert the non-test hunks in a copy; the targeted test must fail. This is the one P1 probe.
   - **Perf probe:** only when per-frame code changed.
   - **Platform matrix read-through:** solo/online × desktop/touch/pad × 16:9/tall/wide.

   Keep each item only if it triggers at least once per 5 R2 tasks.

**Fable adjudicator triggers:**
1. The judge rejects in round 2.
2. The fixer rejected a blocker or major and the judge re-raises it.
3. A cross-lane regression survives one Opus `fix_verify`.

The adjudicator gets the diff, all findings, the fixer's rejections and `gates.json`. It returns the final accept/reject and the exact remaining work.

**Main branch.** Run the train quick and the batch full + mobile gates (§5.8). At close, verify the preserved unrelated files are byte-identical (46 on 2026-09-28).

## 7. Adopt-next-session checklist

1. **Start in the right place.** Launch the root from the MMO worktree (`C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder`), not from AlgoTrading. This removes the "ignore AlgoTrading CLAUDE.md" contamination and the attribution-trailer conflict. Use Opus 5.5 at effort high. Read this doc and the "Repo rules that bite" section of the notes.
2. **Freeze the kit.** Copy the kit to `build/qa/session-<date>/tools/` as v2.
   - Running files are never edited.
   - Every change is a new versioned file written by Codex medium: LF endings, `node --check`, `py_compile` or `bash -n`, plus one dry run.
   - The root switches the kit version in `decisions.json`.
3. **Platform check (10 min, recorded in §8 as P1).** Establish three things:
   - Does `agent()` accept `model` and `effort` per call?
   - Can Workflow agents get the 1-hour cache?
   - What is the first-turn context of a Bash-only agent type, against the 57k median default?
4. **Apply admission control (§5.7) from the first dispatch.** No tooling is needed; use queue depth until the ledger exists.
5. **Write `_header_v2.md`.** Implementers:
   - run no quick, baseline, preflight or full;
   - make one bundled targeted run;
   - report the brief-item ledger;
   - commit after compile plus the targeted check.
6. **Toolsmith tasks to Codex (medium, one lane each, lite review, dispatched in parallel with ideation).**
   - (a) `glock_v2.py`:
     - ledger and `--stats`;
     - P0-P3 with aging and one ticket per lane;
     - `--wait-max`, `--expect` with a minimum runtime, BOM decode;
     - asset canary;
     - refusals for full/preflight below P0 and for non-Godot jobs;
     - bundles;
     - receipts and the cache in shadow mode.
   - (b) The cx_agent seal and `lint_lane.py`.
   - (c) `integrate_gate.sh` per §5.8.
   - (d) `board.py digest` (at most 40 lines, including the $-eq burn from journals) and the defect-ledger append (extend `wfres.py`).
   - (e) The v2 workflows per §3, with explicit model and effort on every `agent()` call.
7. **Keep a control arm.** Until 6e lands, run the v1 `review_lite.js`/`review_fix.js` unchanged. They are the control arm for P2.
8. **Module runner.** After glock v2, dispatch the Codex module-runner and quick-budget task (§5.9).
9. **Ideation.** Run 2 narrowed Codex xhigh rounds and 2 Opus scouts. Keep DeepSeek off.
10. **Dispatcher.** Start `dispatcher.py` only once `board.py` exists, and keep at least 3 approved briefs queued.
11. **Root rollover.** At the first usage-limit reset, if the root's context is over 300k, start a fresh root that boots from the digest plus this doc (P1 of the passive metrics).
12. **Close the session.** A Haiku agent turns the glock ledger and defect ledger into §8 rows, and the root writes the decisions. Commit this doc path-scoped with no trailers.

## 8. Experiment log

Template: `| Date | Experiment | Hypothesis | Setup | Metric | Result | Decision |`

**Results from 2026-09-28**

| Date | Experiment | Hypothesis | Setup | Metric | Result | Decision |
|---|---|---|---|---|---|---|
| 09-28 | Junction vs hardlink farm for `game/assets` | A junction is safe in a sparse lane | Lane a was hand-built with a junction; later lanes got `farm.py` | assets lost | Junction: all 20,267 main assets deleted (I1), 5 min recovery plus a CRLF fix. Farm: 38 s per lane, 0 incidents, 7 clean teardowns | Farm only; never junction a tracked directory |
| 09-28 | glock fairness | Polling is fair enough | 3-5 s polling, then FIFO at 09:50, then per-lane oldest-ticket at 15:10 | max wait | Polling starved a farm job for over 20 min with 9 waiters. FIFO fixed starvation, but one lane still queued 6 jobs (T20). Per-lane round-robin fixed that | Keep; add priority classes (§5.2) |
| 09-28 | Verifier gate re-runs | Re-running the fixer's gates catches defects | 25-26 verifier quick re-runs on fixer-passed trees | verdict changes | 0. Both rejections came from reading and probes | Drop re-runs; the judge reads receipts |
| 09-28 | Lite vs full review (observational) | 1 lens is as good as 3 per token | 11 full reviews, 13 lite (from 12:40) | majors per M tokens | About 1.3 (lite) vs 1.4 (full) behaviour majors per M. Full's surplus was about 12 test-coverage majors, 2-3 of which exposed real defects (T03, T08). Confounded: lite ran on smaller tasks (about 260 vs 450 changed lines) | Route by risk (§6); paired test deferred |
| 09-28 | DeepSeek as an agentic implementer | Cheap second implementer | v4-pro agent: ideation plus 2 implementation runs | $ per run | Balance drained in 3 runs (full context resent every turn); 402 error on the first implementation | Off. If topped up, use only one-shot flash second opinions, after checking the balance |
| 09-28 | Codex narrowed ideation vs Claude scouts | A cheaper model can refill the backlog | 4 Opus scouts; Codex read-only rounds | confirmed bugs, cost | Scouts: 1.33M, 29 proposals, deepest cross-product bugs. Codex round 2: 7 min, 6/6 confirmed, 0 Claude | Codex rounds first, then 2 scouts |
| 09-28 | Batch-only full gate vs quick on main | A batch full every 3-4 lanes is enough | Batch-only until 15:56; quick after each lane from 16:40 | main-red minutes | Batch-only: I6 found late, main red about 50 min, 0.27M to fix. Quick-on-main: 2-3 min per run, passed on ccdc2c9 and 416b516 | Train quick plus lane sync |
| 09-28 | Conflict resolution site | Applying in main is fine | T08 via `git apply --3way` in main; T08m and T13m resolved by Codex medium in the lane | UU files in main | Main: UU files, manual revert. Lane: 12 and 6-7 min, clean afterwards | merge-tree check plus in-lane merges |
| 09-28 | Opus vs Sonnet architect (same throughput lens) | Sonnet 5 matches Opus 5.5 on design analysis | Same prompt and inputs; one run each | grounding, correctness, novelty | See the table below | Sonnet for summaries and consensus checks, not design |

**Architect micro-test detail (n=1).**

| Aspect | Opus 5.5 (throughput) | Sonnet 5 (throughput) |
|---|---|---|
| Evidence base | Re-mined 26 Codex `events.jsonl` (107 glock attempts), fixer and verifier transcripts (135 gaps, 19.5M rewrites) and gate logs (164→182 quick sections) | Only the 3 docs. Said per-role cost data "doesn't exist", although other architects mined it |
| Quantification | Lock-s per task by role, utilization via Pollaczek-Khinchine, work in progress via Little's law, lock-s saved per change | "~66 min", "roughly half", a queue threshold of about 6 with no derivation (at 140 s service that is about a 14-min wait) |
| Correctness | Internally consistent, and its figures match the independent Opus architects (19.5M over 135 gaps) | Left a self-correction in the text ("T02's fixer... actually T01"); "seeds ~29 of the ~24 tasks"; called the v1 root and lens models "Fable (unchanged)" although v1 ran Opus 5.5; described T13's rejection as "merge-adjacent" |
| Novel ideas | `--wait-max 270` against the TTL, async implementer, bundled fail-fast runs, module runner plus quick budget, a tree key that includes the exe hash, a merge train with bisect | A trend-log schema; the "two ceilings" framing |
| Risky recommendations | none rejected | LLM lane managers with the rebuild cost left uncounted; targeted rig instead of the quick; a Sonnet round-1 verifier (all rejected in §9) |
| Overlap | Contains all 3 of Sonnet's core changes (cache, priority tiers, admission) | Found the consensus core |

**What this suggests.** From documents it is given, Sonnet 5 reliably extracts the obvious consensus changes. It does not go and get new evidence, it quantifies loosely, it makes factual slips, and it proposes structurally costly ideas without pricing them. Use Sonnet for summaries, prose from structured inputs, and a cheap "did we miss something obvious" pass. Keep design and analysis that need measurement on Opus. Fable is untested there.

Caveats: this is one run, and neither architect's tool budget nor token cost was recorded. Record both next time.

**Planned (next session)**

| # | Experiment | Hypothesis | Setup | Metric | Success criterion → decision |
|---|---|---|---|---|---|
| P1 | Subagent cache TTL and agent baseline | A 1-hour cache removes most of the 19.5M rebuild cost; a Bash-only agent has a baseline of 25k or less | One R1 lane with a 1-hour cache, if allowed; spawn a Bash-only agent and a default agent from the MMO cwd | post-gap cache-write tokens; first-turn context | Rebuilds cut by at least 80% → adopt the setting, and the gate split becomes optional. Baseline 25k or less → use it for the gate runner |
| P2 | v2 lane workflow vs v1 | Gate offload plus sync cuts Opus $ per lane by 35% or more with no lost catches or escapes | Alternate v1 and v2 per lane, at least 5 lanes per arm, similar sizes, identical lens prompts | Opus $-eq per lane, rewrite $, heavy runs per lane, wall time, judge reject rate, escapes to main, main-red minutes | Opus $ down 35% or more; rewrites under 5% of task $; at most 3 heavy runs in review; wall time no worse; rejects and escapes within noise (v1: 1 regression in 22); 0 conflicts reaching main → v2 becomes the default |
| P3 | Verdict cache (shadow) | Repeats of an already-passed tree are common and never disagree | glock logs would_hit but runs everything, over at least 15 tasks | hit rate by source, disagreements, key compute time | 0 disagreements over at least 20 pairs; key computed in 10 s or less in a lane and 30 s or less in main → enable the cache |
| P4 | Admission cap | Cap 4 keeps throughput and cuts latency | Alternate 2-hour blocks at cap 4 and cap 7 | accepted/h, median and p90 dispatch-to-accept, mean wait by role, $ per task | Cap-4 throughput within 10% of cap 7; median dispatch-to-accept down 35% or more; mean wait 150 s or less → keep cap 4 |
| P5 | Cheaper tiers | Sonnet matches Opus on the R2 tests lens and the R1 combined lens; a Sonnet minor-only fixer is safe; effort high performs like xhigh | Sonnet lenses in shadow on 4 R2 and 6 R1 tasks (the fixer sees only Opus findings); Sonnet minor-only fixer in production; high vs xhigh alternated on the R1 lens over 8 tasks | recall of confirmed majors, false positives, $ per lens, judge rejects | Lens: recall 90% or more, at most 1 extra false positive per task, cost 60% or less → switch. Fixer: 0 rejects over at least 4 tasks at 50% or less of the cost → keep, then trial fused fix+verify. Effort: 15% or more cheaper with majors per 100 lines within 10% → use high |
| P6 | Extra catch sources on R2 | A Codex break-it lens and a Fable judge find majors Opus misses | Codex xhigh read-only break-it review chained after each R2 implementation (tagged `lens=codex`); Fable high judge in shadow on 2-3 per-frame or netcode lanes | unique confirmed majors, rejection rate, OpenAI usage, Fable $ per verdict | Codex: at least 1 unique confirmed major per 4 R2 tasks, 30% or less rejected, OpenAI limit not hit → keep. Fable: at least 1 unique major at $6 or less per verdict → Fable becomes the R2 judge; otherwise trigger-only |

**Passive metrics to record every session:**
- lock utilization, and p50/p90 wait by role;
- lock-s per task;
- $-eq per task by tier;
- root turns and Bash calls per integrated feature (v1: 18 and 12);
- mechanical root errors (v1: 6 or more);
- main-red minutes;
- escapes by stage;
- Codex idle lane-minutes while briefs were queued (v1: 130).

## 9. Rejected and deferred ideas

| Idea | Source | Decision | Why | Revisit if |
|---|---|---|---|---|
| LLM lane managers (Sonnet, 2-3 lanes each) | Sonnet architect | Rejected | A waiting agent rebuilds 135-150k tokens every gap over 5 min: an estimated +0.5-1.5M per lane, to save root turns that cost 1.17M non-cached for the whole day. Subagent Bash is capped at 10 min, and workflows nest only one level | The board-driven root still needs more than 8 turns or more than 5 Bash calls per feature. Then pilot 2 lanes; adopt only at 0.3M overhead per lane or less, 50% or more fewer root turns, and 0 manager errors |
| LLM integration manager | none | Rejected | 21 of 24 applies were mechanical; an estimated 30 wakes × 150k ≈ 4-5M per day | none |
| Fable as default for root, scouts or lenses | Sonnet architect | Rejected (trigger and shadow only) | No v1 evidence of Opus misses, and the window binds first | P6 Fable shadow succeeds |
| Targeted rig instead of the final quick | Sonnet architect | Rejected | The quick suite is the cross-module safety net; rigs are for iteration | Module-runner coverage mapping is proven |
| Sonnet round-1 verifier | Sonnet architect | Rejected | The rejections are the loop's payoff (T02, T13) | P5 results are strong |
| Fused fix+verify for minor-only reviews | quality architect | Deferred | Gives up the independent check that caught T02's fixer-introduced regression | The Sonnet minor-only fixer has 0 rejects over at least 4 tasks |
| Second RAM-gated slot for light jobs | throughput architects | Deferred | A quick run is 3.7 GB; free RAM fell to 0.7 GB; rig RSS has never been measured; the host OOM-crashed on 2026-08-17 | The ledger shows rig/module p95 at 1.5 GB or less; then 20 paired runs with free RAM at 1.0 GB or more, 20% or less slowdown, 0 crashes |
| Async implementer quick (`glock --detach`) | Opus throughput architect | Superseded | G0 in the workflow gets the same effect without a detached worker | none |
| Admission threshold at queue depth about 6 | Sonnet architect | Rejected | About a 14-min wait at 140 s service | none |
| Haiku resolving merge conflicts | none | Rejected | Conflicts go to Codex medium (T08m, T13m came out clean); Haiku only runs clean merges | none |
| LLM log parsing, or verdicts from prose | none | Rejected | I5 and the 12:40 false FAIL were parsing bugs | none |
| Mega-workflow over all lanes | none | Rejected | One edit breaks every resume (I3) | none |
| Codex xhigh for multi-part features | tiering architect | Deferred | Longer wall time, and unproven that majors drop | A session with spare Codex budget: 30% or more fewer majors per 100 lines at 40% or less extra wall time |
| Paired lite vs full review on R2 | quality architect | Deferred | Doubles review cost; wait for risk-routing data | The second v2 session |
| Nightly full run | ARCH_EVIDENCE | Superseded | Train quick, batch full every 4th lane, and final gates cover it | none |
| Root hot-editing the kit | v1 practice | Banned | I3 and I8; the root never implements | none |