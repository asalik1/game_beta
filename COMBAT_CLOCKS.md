# Combat clocks — September 17, 2026

Solo pause now holds the shared player attack windup on its animation's contact
frame. A queued Cleave cannot damage an enemy while its swing and cooldown are
frozen. Online menus keep the world running and committed attacks still resolve.
The first checkpoint covers `cast_wait`, used by eleven kit windups; checkpoint
2 below covers the separate delayed ability/rider timers and world replacement.

Combat report's recent twelve-second window now measures the local player's
gameplay time. Paused menu reading cannot erase wounds before opening the report
or remove an earlier wound from a later fall. The existing personal ending guard
holds this clock with survival; online menus advance it. Last-fall snapshots,
mitigation, overkill clipping, recovery and memory bounds retain their contracts.
The report and Codex explain gameplay time. No save or network format changes.

## Trial transitions (September 21, checkpoint 16)

Trial transition delays follow solo pause and retain their existing durations
and gameplay time scale. Initial/next Crucible spawns, Depths advances and the
final Crucible results delay share one scheduler. A callback belongs to its run
generation, current controller and arena world; ending/replacing them invalidates
old callbacks. Reward math, settlement and save behavior remain unchanged.

Actual Claude supplied the scheduling draft, with independent ownership/world
corrections. Actual DeepSeek supplied an existing-combat-clocks fixture extension;
incomplete output and rejected source drafts remain preserved. Independent QA
adds a controlled real Depths advance. Evidence lives in
`build/qa/session-sept20/trial-transition/`; raw providers and reviewed patches
remain in `trial-transition-candidate/`.

Final acceptance uses 16 successful serial stages: compile-first desktop quick
and full, normal project-specific UID imports, scoped mobile source sync,
mobile compile/strict quick, native trial 30/30 and default combat clocks 30/30
per project, actual paired ENet UI 64/64 per renderer, and early/final strict
preflight. The original orchestration stopped after six successful desktop
stages because a new helper UID had not been imported; normal Godot import
and the remaining stages resumed without repeating or replacing evidence.
UIDs are project-specific and are not copied across projects.
All 36 final native originals received visual review (root 22, peer 24,
ten overlapping trial views). Source and evidence hashes are bound in
`trial-transition/checkpoint-validation.json`; the exact commit and preserved
worktree state are in `commit-receipt.json` there.

The timing behavior is accepted; screenshots also retain separate presentation
debt. Rapid controlled world restarts leave a queued Crucible announcement
visible in Depths; camp guidance is truncated in the compact notification feed,
and Bog/Gorged Tick artwork is visibly pixelated beside the hero and terrain. These
are recorded follow-ups, not blanket visual approval. The first pilot captured
an actual boss-intro painting; final QA waits for its normal completion before
the resumed-play screenshot. The pilot and rejected old-runtime evidence remain.
Host-mobile uses Compatibility rendering, not physical devices. Paired ENet
UI checks do not prove persistence roundtrips. Existing negative-codec and
shutdown diagnostics remain under unchanged strict runner verdicts.

Use `shot.bat combat_clocks --trial-transitions --timeout=300` with isolated
APPDATA under build/qa. This strict mode rejects baseline waivers and other
clock modes. It first waits for the boot opening fade, which owns Escape until
it finishes, so the first native pause is not swallowed. It starts a real
Crucible and pauses natively before first spawn, waits beyond its delay, then
resumes and requires exactly one actual boss. Synthetic counters exercise
inactive/reused-run/controller/world cancellation and a fresh positive. The
Depths camp's unopened-shop warning (September 28) is then driven through the
real camp interactions with a borrowed trash entry checkpoint: the first descend
shows the confirm with Cancel focused, native Cancel keeps the camp, shop and
ledger, a retry still asks, native accept descends and removes the camp,
browsing the shop without buying goes straight down, and a new run warns again
(Escape returns to camp). Checkpoint, hurt cooldown and shop stock are restored
afterward. A loaned cleared trash depth invokes the actual room-clear scheduler,
accrues a controlled pending award, then verifies pause and exactly one
next-wave advance in the same world after native Resume. Six originals show
held/resumed transitions, the fresh camp and the shop warning with Cancel
focused. The Depths phases temporarily protect the low-level hero with the
existing hurt cooldown, restored afterward; AI is frozen after each spawn
observation. The timing phases are timing tests, not victories; the camp phase
is a UI consent check, not a purchase test.

The unchanged runtime failed four strict checks: first boss appeared under
pause, and reused-run/controller/world callbacks fired. Its three originals
and receipts remain retained. The amended Depths case was added afterward.
No ordinary earned trial, final delayed payout, save-write, exact remaining
milliseconds or physical-device proof is claimed. Same-controller restart also
replaces its world; that case does not independently isolate the generation
guard. Native freed-owner and nondefault-time-scale behavior remain untested.

## Depths roster eligibility (September 21, checkpoint 17)

Depths waves exclude enemy definitions explicitly marked `placeholder:true`.
This removes ten retired/future entries from the current 58-kind pool: five
ticks, three Verdant gallery mobs and two library scholars. Their definitions
and archived artwork remain intact. The 48 other non-boss sprite entries keep
their eligibility and ordering; no chapter-placement restriction was added.
Random selection still uses the same algorithm over the smaller eligible pool,
so a given seed can now draw different enemies. Wave count, stats, affixes,
reward rules and the checkpoint-16 transition scheduler are unchanged.

Native CP16 screenshots first exposed 32px tick placeholders beside the painted
hero. `tick-art-audit/` traced the actual imported assets and `scope-review.json`
confirmed that all ten excluded entries remain intended future content. This
is a roster correction, not generated/replaced art or approval of every other
mob. The Codex already places flagged/unplaced entries on its Future shelf;
no new player-facing entry was needed.

Actual DeepSeek supplied a bounded runtime/full-test/native-test draft. Raw
outputs and corrected derivatives remain in `depths-pool-candidate/`. Root
corrected its nonexistent `Enemy.dead` property to actual HP before acceptance.
The partial old-code-v1 run is rejected (29 rows, four originals, script error).
Corrected old-code-v2 completes 34 strict rows: 33 pass and exactly one pool
failure listing all ten placeholders. Its random four-enemy wave was clean,
showing why a lucky screenshot alone cannot establish pool eligibility.

The existing full-tier pool test retains boss fallback/earned-record checks,
restores records before assertions, and checks valid, unique, non-placeholder
mob results plus ordered known-real membership. The existing native trial mode
adds deterministic actual-pool rejection and records every living current-world
wave kind; the expected four actors and all prior 30 timing checks remain.
There is no new screenshot runner or baseline waiver.

All 12 final serial stages pass: desktop compile/quick/full, scoped four-source
mobile sync/import/compile/strict quick, native trial 34/34 and paired ENet UI
64/64 per renderer, then all seven strict preflight categories. Root reviewed
ten final trial originals; peer reviewed all 24 final trial/ENet originals.
Evidence: `build/qa/session-sept20/depths-pool/checkpoint-validation.json` and
`commit-receipt.json`. The old failure and every rejected draft remain retained.

The wave follows a synthetic cleared-depth loan and actual production scheduling,
with temporary survival protection; it is not an ordinarily earned trial,
victory, payout or save-write test. Host Compatibility mobile is not physical
device testing, and UI-only real ENet is not persistence roundtrip proof.
Other unflagged unplaced mobs remain outside this fix. Existing stale queued
Crucible announcements after rapid restarts and truncated camp-feed guidance
remain visible and separate. Known renderer shutdown/negative-codec diagnostics
are retained under unchanged suite verdicts.

## Validation

Accepted evidence is under `build/qa/session-sept17/`. Desktop/mobile gates,
native reviews, strict preflight and the preservation audit pass.

- `initial-preservation.json`: all 46 historical unrelated/experiment files exact,
  initial index empty and HEAD `6d2121aad981714941e60e8e725b13af98da59d6`.
- `initial-hunt.log` and `initial-hunt/`: existing starting-kit Mage hunt won with
  normal health and keyboard movement/casts; root inspected all four native
  frames. Sign positions are setup, so this is combat evidence, not a playthrough.
- `combat-clocks-warrior-hunt.log`: post-fix starting-kit Warrior won through
  keyboard movement/casts in 34.6 seconds, no god mode or injected damage,
  130 starting HP, 113.5 minimum HP, 119.9 ending HP and 120 gold earned. Root
  opened all five native frames. The sign placement remains controlled setup;
  one successful hunt does not establish class balance or a chapter playthrough.
- `combat-clocks-baseline2.log` and its isolated APPDATA: 15 observations, 13 pass
  and exactly two expected defects (lost history and damage during pause).
  `combat-clocks-baseline/` is rejected as a complete baseline: its second exit
  used the wrong button label and never resumed the world. Evidence is retained.
- `combat-clocks-quick.log`: strict desktop quick passes with new domain checks.
- `combat-clocks-full.log`: full desktop suite passes, 225 `ok:` rows; quick has
  145. `combat-clocks-mobile-compile.log` and mobile quick/verdict logs pass.
- `combat-clocks-after/`: 30/30 native checks; mobile-after has 26/26 with touch
  exits (four desktop mouse-helper rows account for the count difference).
  Both runs have zero findings/failures. Root and independent reviewers opened
  all twelve full frames; readable recent/fall/empty reports and touch layouts.
  Reviews: `combat-clocks-visual-review.md`, `combat-clocks-mobile-visual-review.md`.
- `combat-clocks-preflight.log`: full strict preflight passes, including import,
  module, balance, physics, rig, art and engine-backed Codex checks. Scoped mobile
  drift check passes for all nine source/scene paths. UIDs are project-specific.
  `combat-clocks-checkpoint-validation.json` binds source and evidence hashes.
- `combat-clocks-independent-review.md`: independent source/fixture review;
  a temporary wolf invalidated by real respawn was corrected before strict runs.
- `deepseek-review/`: all four API attempts retained, with explicit rejection of
  the broad review's false positives; focused timer reviews corroborate the
  source audit. `claude-deathmark-review.txt` preserves the first expired OAuth
  attempt. After the owner repaired authentication, the authorized Fable review
  succeeded: `claude-deathmark-review-authfixed.txt`. Its landing-overlap advice
  remains a source-level candidate, not an accepted fix or runtime proof.

Run `shot.bat combat_clocks --timeout=240` with fresh isolated APPDATA. Add
`--mobile --renderer=gl_compatibility --touch` for mobile source and emulated
ScreenTouch exits on the Windows host. The rig covers pause beyond the history
window, frozen swing/cooldown/animation, eventual one-time contact, real solo
defeat/recovery, retained last-fall history, active expiry, an empty loopback ENet
host with live menu clocks, and a direct personal-ending guard probe.

The rig deliberately poses a frozen enemy and calls production damage/cast entry
points. Menu exits use real input. It does not establish ordinary combat balance,
every kit's timing, exact subframe contact delay, remote replication or physical
device behavior. The history clock follows the protected reader's survival;
already committed attacks follow the shared world, as existing projectiles do.

## Checkpoint 2 — delayed effects and world lifetime

The follow-up changes twelve gameplay timer callsites and four duration-linked
indicators to respect solo pause: Mist; Ashrider/Fury/Aftershock; Wrath,
Consecration, Aegis blessing and Chains; Death Mark; two mage impact paths;
Rift; mark X, Aegis crests/orbit and Voidwraith tentacles. Delays and damage
coefficients stay unchanged. Nine named constants in `balance.gd` retain the
existing durations and Mist tick interval. The authored Void Weaver helper currently has no
production caller; that one check directly invokes it, not a live skin selector.
Projectile-eye cleanup fuses and unrelated short cosmetic timers stay separate.

Pending offensive effects also keep the identity of the world where they began.
Chapter restart/travel replaces that world while retaining the Player, so old
attacks now cancel rather than striking fresh enemies. `cast_wait` reports that
cancellation to all eleven callers before restoring its captured theme payload.
Existing focus/eye cleanup and dead/target guards remain. The personal Aegis
buff already survives travel; its expiry blessing stays with that buff.
Indicator cleanup still runs on its normal schedule. This is not a new policy
for same-world death, personal finales or every visual lifetime.

Evidence (`build/qa/session-sept17/`):

- `ability-timers-baseline2/`: 73 observations, exactly sixteen expected pause
  findings, no unexpected failures. `ability-timers-after/` first passes 73/73.
  Root opened all six images; the first Mist framing was poor and preceding
  effects lingered in other captures. Numeric evidence is retained, with final
  camera settling and quiet-time checks completed in the accepted final2 captures.
- `ability-lifetime-baseline/`: real chapter replay reproduces both old Cleave
  and Aftershock striking fresh-world targets. The expanded `baseline2/` has
  19 observations and exactly three findings, adding stale theme restoration.
  New-cast positive controls and personal Aegis travel/heal controls pass.
- The first lifetime patch incorrectly cancelled only Aegis healing while its
  buff survived travel; review rejected it before application. Retained as
  `ability-timers-candidate/lifetime/rejected-v1-cancelled-personal-heal.patch`.
- The first compile attempt used the wrong path; its failure is retained in
  `ability-timers-baseline-compile.log`. Correct compile and desktop quick pass.
- The first full strict preflight found twelve unchanged duration literals on
  edited timer lines. `ability-timers-preflight.log` retains this rejected gate;
  final2 centralizes their exact values in `balance.gd` and reruns validation.

Final acceptance: `ability-timers-final2-*` and `ability-timers-mobile2-*`.
Desktop quick/full pass (145/225 rows); mobile import, compile (264 scripts),
strict quick (145 rows) and eleven-path exact mobile sync pass. Native desktop
lifetime/effects/history pass 19/73/30 checks; host mobile with touch HUD passes
19/73/26, including the empty-host live-menu control. Full strict preflight passes
without warnings. Root opened all twenty-two final2 native frames; the earlier
equivalent final candidate also has independent reviews of all ten new-mode
frames. The final2 constants review proves exact numeric/source equivalence.
`ability-timers-checkpoint-validation.json` binds final source, evidence, actual
commit and the exact forty-six-file preservation audit.

These screenshots are controlled timing illustrations. Immediate pause captures
Mist before its cloud fade-in; Aegis HUD retains the pre-fixture HP while the
receipt checks actual HP. Borrowed kits retain the Warrior body. Full quest,
resources, targets, reports and touch controls fit; no full-animation or normal
skin progression claim follows from these held frames.

`shot.bat combat_clocks --effects` exercises posed production entry points and
exact baseline findings; `--lifetime` exercises real replay with frozen actors,
direct Warrior casts and the direct Aegis helper. Its borrowed actor is not a
normally progressed Paladin. These checks do not establish every offensive
continuation's lifecycle independently, exact damage/hit counts for every effect,
ordinary skin play, remote replication, physical-device behavior, or exact
subframe timing. The original default mode retains native menu input and empty
loopback-host controls. Use fresh isolated APPDATA for each mode.

## Death Mark cross-cast payload isolation (checkpoint 4)

A missed Poison Stab cast during Death Mark replaced the ultimate's shared
payload. Its later strikes then applied Poison Stab's toxin/slow and used its
theme color. The original source reproduced exactly three named findings in
35 checks. `payload-baseline-validation.json` binds that production revision,
QA source and evidence; the failed behavior remains preserved.

Death Mark now owns a deep copy of its effects, color, themed flag and cast base.
Each synchronous strike borrows that copy and immediately restores the latest
ambient payload before any wait. The final arc and optional Shadow execute share
one scope. Capture/restore helpers also replace the existing equivalent copy in
`cast_wait`; its dictionary identity, pause and world-cancellation behavior are
unchanged. Coefficients, timers, landing resolution, live stats and skin branches
are unchanged. This does not add caster-death cancellation.

`shot.bat combat_clocks --payload --payload-extra --timeout=180` tests production
calls with frozen actors. It lends L5 Poison/L15 Shadow access without recalculating
starting combat stats. Reference and crossed casts retain the same ordered three
(or four) damage hits; a whiff adds no statuses, while a close Stab still adds
poison and slow. Target removal and real replay cancel further contact/blink and
preserve the newer payload; fresh casts still work. Replay also removes the old
target, so that case does not isolate world identity from target validity. Extra
cases are strict-only; `--payload --baseline` permits exactly the original three
findings and demands their exact old status/payload signature. Receipts live in
`combat_clocks/payload/`; captured frames show the aftermath, not every strike.

`shot.bat guest_blink_enet --deathmark --payload --timeout=180` adds native
ultimate-then-Stab input to both transport landing cases. A lent actual L5 sheet
is recalculated and remains unchanged; physics is held after each input edge.
The Stab's real arc must miss before teleport. Exact guest-owned host damage,
HP/position convergence, no unwanted host/mirror statuses and newer ambient state
are required. A separate close Stab must replicate poison/slow positively.
APPDATA must be isolated under `guest-blink-enet-candidate`; outputs are under
`guest_blink_enet/deathmark/payload/`. Manual admission, stationary target and
local ENet are controlled fixtures, not ordinary moving co-op or device testing.

Final acceptance: desktop quick/full (145/225), mobile import/compile (267) and
strict quick (145), exact five-source sync and full strict preflight pass.
Expanded payload checks pass 76 on each project; native ENet payload checks pass
101 each, with the default desktop Death Mark transport regression passing 68.
Shared lifetime/effects regressions pass 19/73 each. A normal-input starting
Assassin hunt wins in 23.262s with an observed execution/landing and nine reviewed
frames; setup is posed, combat stats/input are ordinary. Root opened all 60
native originals across baseline, strict, regression, hunt and mobile runs;
thirteen also received independent image review. Receipt:
`build/qa/session-sept17/payload-checkpoint-validation.json`.

The four fields are observed, but legal casts here both have cast base zero;
no contrasting nonzero-base acceptance is claimed. Source review covers shared
skin contacts; these runs use the base Assassin. No physical mobile device was
tested. Rapid reset captures retain marks/small-bar presentation and the damage
meter can lag contacts; per-hit and authoritative HP/status receipts provide the
exact oracle. Hunt cards/posed Tovin prompts can overlap nearby action; this is
not a broad UI clearance acceptance. Existing shutdown RID/texture/ObjectDB
warnings remain recorded by the unchanged runner; the full suite retains its
intentional invalid-base64 negative-test diagnostic.

The first mobile ENet attempt failed its pre-teleport observation window after
58 checks; all four frames and receipt remain preserved. Contact timing was
ambiguous because the polling wait delayed input and the next physics sample
could follow both contacts. Final2 QA arms native Stab directly from the observed
ultimate edge, requires a follow-up within two physics ticks and retains every
spatial/damage/status guard. Production and all other QA source are byte-identical
to the first final runs. Final2 desktop/mobile payload and default transport,
quick/full/mobile suites and preflight pass.

## Further candidates

Death Mark landing clearance is checkpoint 3 in EXPLORATION_RELIABILITY.md.
Other delayed riders identified in
`build/qa/session-sept17/delayed-payload-candidate-review.md` remain source-level
candidates requiring independent reproduction and bounded acceptance.
