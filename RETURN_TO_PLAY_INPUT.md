# Return-to-play input buffering

A fresh keyboard ability tap accepted just after a menu or dialogue closes now
survives the controller adapter noticing the return to gameplay. The adapter
still clears pending actions on observed transitions into non-play contexts;
held-controller rearming, pointer cancellation, focus/disconnect behavior and
normal input authority remain unchanged.

The production change is one condition in `scripts/gamepad.gd`. Claude Code
proposed it; Codex repaired its malformed patch/comment and authored the native
extension. The raw Claude domain helper remains rejected and preserved. The
optional `shot_controller.gd` hook loads `scripts/tests/pad_context_live.gd` only
for `--pad-context`; the existing default controller workflow remains available.

Desktop quick 147/full 227, mobile quick 147, compiles, three-source mobile sync and strict preflight passed. Baseline has 34 rows and exactly menu.fresh_tap_retained/dialogue.fresh_tap_retained findings; strict desktop/mobile have 34/34 rows and zero findings/failures. All 33 baseline/final originals were independently reviewed: five focused images per run and nine default controller images per platform. New helper UIDs are pinned separately per project; existing sidecars remain unowned.

The focused fixture drives actual key/pad events, normal local physics and the
normal adapter process in a disposable no-save solo village. It borrows a 120 ms
basic cooldown and a synthetic one-line dialogue. Strict timing prerequisites
prove the new tap was accepted while the adapter still cached the overlay and
that its buffer had neither fired nor expired before the adapter returned to
play. Fixed runs require an actual cooldown restart; baseline runs require no
cast. Entry cancellation, under-menu rejection, settled-play casting, held-pad
release/rearm, unchanged HP/XP/gold and released keys remain strict controls.
Only `menu.fresh_tap_retained` and `dialogue.fresh_tap_retained` may be baseline
findings. A timing failure is rejected evidence, not another expected defect.

Run `shot.bat controller --pad-context --timeout=180` in a fresh isolated APPDATA;
add `--baseline` only to reproduce the reviewed old production. Run the default
`shot.bat controller --timeout=240` separately. Mobile uses the established
source-only sync, then `--mobile --renderer=gl_compatibility --touch`. Each project
owns its resource UIDs; helper UIDs are independently pinned and existing UIDs
are unowned. No sidecar is copied between projects.

This is controlled input ordering, not an ordinary encounter or a measured rate
of occurrence. Basic cooldown restart proves a cast rather than damage or target
identity. The focused mobile run injects keyboard/pad events with a touch HUD on
the Windows host; it does not establish physical-device/controller or ScreenTouch
gesture coverage. The default controller regression includes actual synthetic
touch handoff and simulated unpaused-overlay policy, not ENet authority. No RPC
or transport change is involved, and these receipts make no new online claim.
No complete gameplay-state snapshot/restore or earned-reward journey is claimed.

The runner records numeric phases separately from original-image review. Raw
helper rejection, line-ending corrections, explicit support rebases and the UTF-8
runner correction remain in ignored session evidence. Desktop native logs retain
the established texture-RID/RenderingServer shutdown diagnostics allowed by the
unchanged screenshot verdict; mobile native logs contain none of those warnings.
Headless suites retain their established ObjectDB exit warning. Passing gates
do not establish clean renderer teardown. The durable checkpoint receipt records
measured counts, exact source/support pins, separate project UIDs and visual
evidence. Mobile controller help extends below an ordinary scroll boundary, so
these captures do not establish that every instruction is visible simultaneously.
