export const meta = {
  name: 'crownless-fix-verify',
  description: 'Resume a Crownless lane: Claude fix (from given findings) and/or independent verify',
  phases: [
    { title: 'Review', detail: '3 read-only lenses over the lane diff' },
    { title: 'Fix', detail: 'one fixer verifies + applies findings, runs gates, commits on the lane' },
    { title: 'Verify', detail: 'independent verifier re-runs gates and judges accept/reject' },
  ],
}
const A = args
const Q = 'C:/Users/asali/Projects/MMO/.codex/worktrees/crownless-wayfinder/build/qa/session-sept28'
const GLOCK = `python ${Q}/tools/glock.py`
const CTX = `You are working on Crownless (Godot 4.4 action-RPG) task ${A.task}: "${A.title}".
Lane worktree: ${A.lane} (git branch ${A.branch}); base branch: codex/crownless-wayfinder.
The implementer (Codex) brief: ${Q}/briefs/${A.task}.prompt.md — read it first.
The implementer's final report: ${Q}/runs/${A.run}/last_message.md.
The change under review = \`git -C "${A.lane}" diff $(git -C "${A.lane}" merge-base HEAD codex/crownless-wayfinder)\` (committed + uncommitted; ALWAYS diff against the MERGE-BASE — the base branch keeps moving as other tasks land, and a plain diff against it would show their work as deletions; also \`git -C "${A.lane}" status --short\` and \`git -C "${A.lane}" log --oneline codex/crownless-wayfinder..HEAD\`).
Project practices: ${A.lane}/CLAUDE.md (read "Code layout", "Testing", "GDScript traps", "Multi-agent etiquette"). Ignore any AlgoTrading CLAUDE.md you may have been given — it is unrelated.
SAFETY: the lane is a SPARSE worktree; game/assets is a HARDLINKED copy of the main worktree's assets and game/.godot is a JUNCTION into it — never modify/delete/re-checkout anything under them, never run \`git clean\`, \`git sparse-checkout\`, \`git stash -u\` or \`git checkout/restore\` on those paths, never touch other lanes or the main worktree. To compare against old code, copy the specific source files aside and back (as earlier fixers did), never reset the lane. mobile/ is intentionally absent.
Player-facing text house style: plain casual English, NO em dashes (—) in new player-facing strings, no CAPS for emphasis, never drop details.`

const FINDINGS = {
  type: 'object',
  properties: {
    verdict: { type: 'string', enum: ['clean', 'issues'] },
    findings: { type: 'array', items: { type: 'object', properties: {
      severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
      title: { type: 'string' },
      detail: { type: 'string', description: 'what is wrong, the concrete trigger, and why it matters' },
      location: { type: 'string', description: 'file:line' },
      suggested_fix: { type: 'string' },
    }, required: ['severity', 'title', 'detail', 'location', 'suggested_fix'] } },
  },
  required: ['verdict', 'findings'],
}
const LENSES = [
  { key: 'correctness', prompt: `${CTX}

LENS: CORRECTNESS. Read-only: do not edit files, do not run Godot. Does the diff actually solve each part of the brief (or correctly skip a part whose premise was false — check the implementer's reasoning yourself)? Walk every changed function and every caller of changed functions. Hunt for: new bugs, missed entry points/call sites that still use the old behavior, co-op/online issues (host authority, guest peers, the tree pause no-ops online, per-player loot ownership), mobile touch and controller paths, stale callbacks after panel rebuild/scene change, freed-node access, double-grant/duplication, state not restored on failure paths, GDScript traps from CLAUDE.md. Report only real problems with a concrete trigger; do not pad with style nits. Empty findings is a fine answer if the change is correct.` },
  { key: 'tests', prompt: `${CTX}

LENS: TESTS. Read-only: do not edit files, do not run Godot. For each regression test added/changed: would it FAIL on the base code (codex/crownless-wayfinder) and PASS on the new code? Is it actually wired into a suite tier or rig that gets run (quick tier / full autotest / a shot.bat rig — trace how)? Deterministic (wall-clock waits for physics/timers, no reliance on loot luck or state accumulated by earlier sections)? Does it snapshot + restore shared state, including on failure paths? Does it cover each part of the brief that was implemented? Missing coverage of an implemented behavior is a major finding. Report concrete problems only.` },
  { key: 'scope', prompt: `${CTX}

LENS: SCOPE, RULES AND PLAYER EXPERIENCE. Read-only: do not edit files, do not run Godot. Check: unrelated or gratuitous changes; bare tuning numbers that belong in game/scripts/balance.gd; new class_name (forbidden in lanes); per-frame cost added to hot paths; player-facing copy (clear, casual, no em dashes, accurate, not misleading); whether the in-game codex or a hand-maintained list must change (CLAUDE.md codex rule); whether the change behaves sensibly on the mobile touch HUD and on controller; whether it could annoy players (spam, modal interruptions, lost input); files committed that shouldn't be (logs, junction paths). Report concrete problems only.` },
]

const FIX = {
  type: 'object',
  properties: {
    applied: { type: 'array', items: { type: 'string' } },
    rejected: { type: 'array', items: { type: 'string' }, description: 'finding title + why it is not a real problem' },
    compile: { type: 'string', description: 'COMPILE OK or the error' },
    quick_suite: { type: 'string', description: 'PASS/FAIL + key lines, or not-run with reason' },
    targeted_tests: { type: 'string', description: 'which module/rig ran, exact command, result' },
    commits: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
  required: ['applied', 'rejected', 'compile', 'quick_suite', 'targeted_tests', 'commits', 'notes'],
}
const VERDICT = {
  type: 'object',
  properties: {
    accept: { type: 'boolean' },
    blockers: { type: 'array', items: { type: 'object', properties: {
      severity: { type: 'string', enum: ['blocker', 'major', 'minor'] },
      title: { type: 'string' }, detail: { type: 'string' }, location: { type: 'string' }, suggested_fix: { type: 'string' },
    }, required: ['severity', 'title', 'detail', 'location', 'suggested_fix'] } },
    player_summary: { type: 'string', description: 'one or two plain sentences: what a player gets from this change' },
    tests_run: { type: 'string' },
    risk_notes: { type: 'string' },
  },
  required: ['accept', 'blockers', 'player_summary', 'tests_run', 'risk_notes'],
}

const GATES = `Gates you must run in the lane (Git Bash, cwd = lane):
- Compile gate (unlocked, ~35 s): \`./tools/Godot_v4.4.1-stable_win64_console.exe --headless --path game --script res://check_compile.gd\` → must print COMPILE OK.
- Quick suite (heavy, ~3.7 GB → through the machine-wide lock, which builds the command and checks the pass marker): \`${GLOCK} --cwd "${A.lane}" --log "${A.lane}/build_lane_logs/<name>.log" --suite quick\` → trust only \`[glock] SUITE VERDICT: PASS\`.
- The targeted regression module/rig the change added or touched, run the way that module is normally run (see shot.bat, tools/INDEX.md, the module header, or the autotest tier), also through glock: \`MSYS_NO_PATHCONV=1 ${GLOCK} --cwd <lane> --log <log> -- cmd.exe /d /c <absolute lane path>/shot.bat <rig> ...\` (without MSYS_NO_PATHCONV Git Bash rewrites /d /c and nothing runs; a 0-second exit 0 is NOT a pass). If the module runs inside the quick tier, the quick run covers it. Never run the full test.bat (the integrator does).
Never report a pass you did not see in the output.`

// fix_verify variant: no review phase. args.findings (array) → fix first; or args.fix (object) → verify first.
let findings = A.findings || []
let fix = A.fix || null, verdict = null
for (let round = 1; round <= 2; round++) {
  phase('Fix')
  if (!(round === 1 && A.fix)) fix = await agent(`${CTX}

ROLE: FIXER (round ${round}). Independent reviewers reported the findings below (JSON). For EACH finding: verify it against the code yourself. If it is real, fix it properly in the lane; if it is not real, reject it with a one-line reason. Minor findings: fix when cheap and clearly right, otherwise reject with reason. Also fix anything else you notice that would block acceptance. Keep changes surgical and within the brief's scope.

FINDINGS:
${JSON.stringify(findings, null, 1)}

${GATES}

Then commit your fixes on the lane branch (\`git -C "${A.lane}" add <explicit paths>\` + commit; a plain subject like "Review fixes: ..."; NO co-author/attribution trailers; never add build_lane_logs/ or junction paths). If the implementer left uncommitted work that belongs to the change, commit it too. Report exactly what ran and what it printed.`,
    { label: `${A.task}:fix:r${round}`, phase: 'Fix', schema: FIX })

  phase('Verify')
  verdict = await agent(`${CTX}

ROLE: INDEPENDENT VERIFIER. A fixer claims (JSON): ${JSON.stringify(fix)}
Judge whether this lane is ready to integrate. Do it yourself, do not trust claims:
1. Read the full final diff vs the merge-base with codex/crownless-wayfinder and the brief. Confirm the change does what it says, nothing unrelated slipped in, and there is no remaining blocker/major defect (correctness, co-op/mobile/controller cross-products, stale callbacks, state restore, GDScript traps, copy style).
2. Run the compile gate and the targeted regression module/rig yourself (through glock). If the fixer did not run the quick suite successfully, run it (through glock).
3. Make sure the lane is fully committed (\`git status --short\` shows only build_lane_logs/ or nothing).
${GATES}
accept=true only if gates pass and no blocker/major remains. List remaining problems as blockers (severity major/blocker ones prevent acceptance; minor ones may be listed but do not block).`,
    { label: `${A.task}:verify:r${round}`, phase: 'Verify', schema: VERDICT })
  if (!verdict || verdict.accept) break
  findings = verdict.blockers
  log(`${A.task}: verifier rejected round ${round} with ${findings.length} issues — another fix round`)
}
return { task: A.task, lane: A.lane, branch: A.branch, review_findings: (A.findings||[]).length, fix, verdict }
