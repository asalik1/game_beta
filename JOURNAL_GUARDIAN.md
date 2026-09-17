# Quest journal guardian status

When a room has zero ordinary monsters but its authored guardian is unresolved,
the Journal main quest card now says “Current room · guardian remains.” Nonzero
ordinary-monster counts retain their count wording; resolved and no-boss rooms
retain the clear message. Completing the guardian refreshes an already-open
Quests reader while preserving its established scroll and named focus.

The display uses the existing shared guardian resolver. Named pocket, Unlisted
and Waking encounters retain their own completion state independently of a reused
campaign boss kit. This changes presentation and reader invalidation, with no
new guardian completion rule, spawn, combat, reward, quest-timing or teaching gate.
The context strip still reports ordinary monsters; optional road hunts are not
reclassified as authored room guardians.

Desktop quick 147/full 227 and mobile quick 147 passed, with desktop/mobile imports and compiles, exact four-source sync, strict preflight and both default reader regressions. Baseline recorded 25 checks and exactly four expected findings; strict desktop/mobile recorded 25/25 checks with zero findings/failures. All 40 baseline/final originals were independently reviewed. Each project UID is pinned separately.

Use `shot.bat menu_navigation --quest-guardian --timeout=240` with fresh isolated
APPDATA under build/qa. `--baseline` requires exactly `pending/text`, `live/text`,
`named/text` and `watch/rebuilt`. The first three require the exact old clear
string; missing or unexpected text remains fatal. Strict mode permits no
findings. Add `--mobile --renderer=gl_compatibility --touch` for the host-rendered
mobile-source check. Run the default menu_navigation route separately.

Eight focused originals cover pending authored Fangmaw metadata, a live frozen
factory boss, resolved guardian, ordinary count, safe room, named encounter,
resolution under the open scrolled reader, and close/reopen. The watcher oracle
observes shell identity, actual nonzero scroll, named focus, and independent
snapshots with only pocket_done changed. It does not call the new production
signature as its oracle. Input uses actual mouse/ScreenTouch dispatch and Escape.

These are disposable no-save reader fixtures. The hero stays near the village;
the actor is assigned the arena identity without traveling or clearing it.
Molten Court metadata is projected into that slot because Chapter 1 does not
naturally inject a pocket. No earned victory, genuine pocket entry, save-enabled
daily board rollover, co-op delivery or physical-device behavior is established.
The ordinary refresh_bounties/refresh_contracts calls are no-ops under no_saves.
The deliberately scrolled watcher image is paired with a reopened main-card
capture. Stored text assertions do not replace original-image readability review.

The established screenshot runner permits its documented RendererRD/null
RenderingServer shutdown diagnostics; passing evidence does not assert an
error-free renderer teardown. Script/parser errors remain fatal. Each project
owns its generated helper UID; source syncing intentionally excludes .uid files.

Actual DeepSeek v4-pro production output and request/response provenance are
preserved under build/qa/session-sept17/deepseek-quest-candidate. Its first native
helper proposal is rejected and retained under native-v1. The accepted candidate
helper is a locally corrected rewrite recorded under native-v2, with independent
cross-file review. The later native-v4 fixture disables inherited Game actors,
including direct Chest/Pickup children, while explicitly ALWAYS HUD/Menus and the
reader watcher stay live. It drains queued setup callbacks before economy
snapshots and retains strict cleanup assertions with changed-field detail.
Baseline1's lone cleanup failure remains rejected with its cause unidentified;
the diagnostic trace and narrower v3 isolation attempt are preserved separately.
This fixture correction is not claimed as a production defect fix or represented
as unmodified model output.

Exact source pins, gate logs, reviews, rejected evidence, owned paths and final
commit are recorded in build/qa/session-sept17/journal-guardian-checkpoint-validation.json.
