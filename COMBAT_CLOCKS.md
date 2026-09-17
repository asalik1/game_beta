# Combat clocks — September 17, 2026

Solo pause now holds the shared player attack windup on its animation's contact
frame. A queued Cleave cannot damage an enemy while its swing and cooldown are
frozen. Online menus keep the world running and committed attacks still resolve.
This change covers `cast_wait`, used by eleven kit windups; the separate delayed
ability/rider timers listed below are follow-up work.

Combat report's recent twelve-second window now measures the local player's
gameplay time. Paused menu reading cannot erase wounds before opening the report
or remove an earlier wound from a later fall. The existing personal ending guard
holds this clock with survival; online menus advance it. Last-fall snapshots,
mitigation, overkill clipping, recovery and memory bounds retain their contracts.
The report and Codex explain gameplay time. No save or network format changes.

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

## Follow-up candidates

The read-only timer audit identifies twelve other gameplay timers, plus buff
indicators, that remain pause-immune. Reproduce and fix these as a separate
checkpoint; do not describe all ability effects as fixed by `cast_wait`.
The same audit notes possible Death Mark landing overlap and delayed-rider theme
contamination; neither is accepted as a runtime-confirmed defect yet.
