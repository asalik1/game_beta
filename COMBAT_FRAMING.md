# Combat framing and movement recovery

Continues the autonomous improvements on `codex/crownless-wayfinder`.

## Changes

- The camera composes around the hero and the current aim target. The old
  8% combat zoom-in could push a ranged opponent entirely offscreen. The new
  view eases toward a bounded shared center and widens only when needed;
  close fights and exploration retain the base zoom. It uses the existing
  targeting rules, excludes enemies in other rooms and resets its composition
  after a teleport, room change or character replacement. Easing is independent
  of frame rate. Camera lead scales the shared-center displacement; Combat
  framing can be disabled. Ordinary lead uses the camera's local position so
  the engine applies room limits; only impact shake uses the post-limit offset.
- Mob, boss and duel-rival health bars show a gold lost-health trail. Repeated
  hits refresh its brief hold, then it drains to the actual health. Healing and
  changing targets reset it immediately, so neither invents damage.
- Enemy and local-hero physics reject invalid movement before it can reach
  position or the speed-coupled animation clock. Invalid physics results restore
  the immediately preceding position; a pre-existing invalid position recovers
  to safe room/home ground. Recovery also clears poisoned animation phases.
  Both actors now use top-down floating collision mode, without floor snapping
  or treating other actors as moving platforms. Stride clocks read actual travel,
  including stopping against a wall. Straight-line speed, damage, rewards and
  collision dimensions are preserved.
- Each actor retains a non-persistent recovery count and the last bad motion
  values for diagnosis. Dev mode prints them; the motion rig treats an unexpected
  recovery as a failure, so a guard cannot hide a recurrence during QA.
- Combat hints tolerate an opponent being freed while a menu pauses target
  refresh. Touch controls now update visibility through solo pause, start hidden
  when created under a menu and return when gameplay resumes.

## Reproduction

`shot.bat framing --no-import --fault-probe --timeout=180` deliberately applied
one invalid gust to a moving six-frame wolf, then restored the valid gust.
Before the fix, the body returned to the world but its animation clock stayed
NaN. Four successive updates emitted the exact native error seen during the
earlier recording: `Index p_frame = -2 ... (vframes * hframes = 6)`.
The regression reported failure in `build/qa/framing-probe-before.log`.

The first instrumented live-combat run then caught a natural recurrence on a
blightwolf after 1,774 reviewed frames, with zero gust and knockback. Its position
and velocity became invalid; the new boundary recovered it, and the rig correctly
failed on the recovery rather than silently accepting it. Log:
`build/qa/framing-motion-warrior.log`.

Inspection found both actor classes still used Godot's grounded/platformer
defaults. In addition, hit-stop set time scale to zero while collision steps
continued. Godot 4.4's `move_and_slide` divides displacement by delta to compute
real velocity. Actors now use floating mode, disable platform inheritance and
skip collision steps at zero delta. A live overlapping-body hit-stop probe
checks frozen positions, frozen clocks and finite measured velocities.

References: [Godot motion modes](https://docs.godotengine.org/en/4.4/classes/class_characterbody2d.html#enum-characterbody2d-motionmode)
and [the bundled version's collision implementation](https://github.com/godotengine/godot/blob/4.4-stable/scene/2d/physics/character_body_2d.cpp#L34).
The platform/hit-stop combination is the supported explanation for the natural
recurrence; the original recording did not identify its exact first collision.

## Repeatable QA

- `test_quick.bat`, then `test.bat`: includes camera bounds, empty/close/ranged
  composition, zero-lead preference, health trail holds/heals/identity and
  transient/legacy-invalid movement recovery for both actors.
- `shot.bat framing --no-import --timeout=240`: real-renderer comparisons for
  distant east/north opponents, health loss and recovery, exploration and the
  boss/touch comfort controls. It also drives both hero and wolf into an isolated
  wall in all four compass directions, checking approach, collision blocking and
  zero measured speed while blocked. Captures under `user://shots/framing/`.
- `shot.bat polish --gif --no-capture --passes=3 --seed=907 --zoom=1.12
  --fixed-fps=30 --no-import --timeout=240`: live keyboard movement and abilities
  across forest/keep fights, road, magma and north-wall approaches. Per-frame
  clock/position/recovery checks remain active without expensive PNG readbacks.
  Omit `--no-capture` to produce reviewable frame series.

## Original verification results

- Desktop import, compile and full campaign suite: **PASS**, 176 reported
  checks. `build/qa/framing-full-final.log`.
- Mobile import, compile and strict quick-suite verdict: **PASS**, 95 reported
  checks. `build/qa/framing-mobile-final.log`, `framing-mobile-suite.log` and
  `framing-mobile-import.log`.
- Final motion checks: **PASS**, all six base classes, 5,775 frames total
  (two Warrior passes; one each for Archer, Mage, Assassin, Paladin and Warlock).
  No unexpected motion recoveries, script errors or negative frame indices.
  Logs: `build/qa/framing-motion-<class>-final.log`.
- Earlier six-pass Warrior soak: **PASS**, 4,950 frames after the floating-mode
  and hit-stop fix, before the final measured-travel refinement.
  `build/qa/framing-motion-fixed.log`.
- Real-renderer QA: **PASS**, 13 screenshots including east/north before/after,
  mob and boss damage trails, exploration, desktop and touch comfort.
  `build/qa/framing-visual-final.log`. Images:
  `build/qa/framing-final-render-user/Godot/app_userdata/Crownless/shots/framing/`.
- Live hit-stop and four-direction collision/stride contracts: **PASS**.
  `build/qa/framing-collision-final.log`. The rig's updated compile gate also
  passed (`build/qa/framing-rig-compile-final.log`).
- Preflight: **0 failures, 6 existing structural warnings** (protocol bit
  packing and epsilon guards). `build/qa/framing-preflight-final.log`.
- Desktop/mobile source parity: **18 files, zero drift**; each project creates
  its own script UIDs. `build/qa/framing-mobile-parity.log`.

The ordinary renderer-shutdown texture/RID diagnostics remain, matching the
unchanged baseline. The full suite's deliberate invalid-Base64 diagnostic and
bare ObjectDB shutdown warning are accepted by its existing strict verdict.
No live multi-client soak or physical-device mobile build is claimed.

Those results describe the original framing checkpoint. Current session results
and commit receipts are recorded in `AUTONOMOUS_STATUS.md`.

## Room-edge lead correction — September 17

At the north wall, locking an opponent 170 world units south could push the
hero's head and upper body beyond the top of the viewport. The lead was assigned
to `Camera2D.offset`, which bypasses camera limits. The live baseline reproduced
the body proxy's top at approximately -53.5px across 20 settled rendered samples;
native PNGs confirm painted-body clipping. No-target and zero-lead controls
restore visibility without moving either actor. Zero lead also changes composition
zoom, so this is a comfort-setting comparison, not an offset-only experiment.

The same eased lead now uses `Camera2D.position`, before room clamping. Shake
retains its existing offset and comfort preference. Target eligibility, combat
zoom calculation, movement, damage and room limits are unchanged. The frozen
legacy before-framing screenshot explicitly resets both local position and
offset so a preceding live comparison cannot contaminate its reference.
See [Godot 4.4 Camera2D](https://docs.godotengine.org/en/4.4/classes/class_camera2d.html)
for offset/limit and actual screen-center behavior.

`shot.bat framing --north-edge --camera-lead --camera-edges --timeout=300`
checks live smoothing, default lead, native Tab/Space targeting, target removal,
held travel to north/south/one clear side edge, and menu/room restoration. Use a
fresh isolated APPDATA; add `--mobile --renderer=gl_compatibility --touch` for the
mobile source rendered on the host. `--camera-baseline` expects only the original
north hero-containment finding and must omit `--camera-edges`, `--extra` and the
older tracker `--baseline` flag. Nested camera evidence is written alongside the
parent north-edge receipt under `camera_lead/acceptance.json`.

The fixture removes enemies and delays hazards, retains walls/props, and freezes
factory wolf AI. Initial placement and room restoration are direct; route travel
and locking use real input. Body proxies measure viewport containment, not clear
painted silhouettes or touch-button clearance. Wandering NPC overlap in the
prototype/extended north target pose is preserved as partial presentation
evidence. Small rooms, extreme zoom, transient shake and arbitrary HUD overlaps
are not universally guaranteed by this correction. Physical-device testing is
not claimed.

Final validation: desktop quick/full **145/225**, mobile import/compile **276
scripts** and strict quick **145** pass. Desktop and host mobile/touch edge
probes pass **37 parent / 88 nested** checks each. Existing distant-framing
captures pass on both projects; desktop tracker **365/29** and real local ENet
cast regressions pass. Six source mirrors and full strict preflight pass.

The ordinary-input hunt now supports `--live-camera`, retaining and verifying
default combat framing, lead and smoothing; its legacy mode still disables
framing/smoothing. Both retain zero shake and direct sign setup. Starting-kit
Mage live-camera runs win in **15.772s** desktop (minimum/end **3.075552/90 HP**)
and **16.275s** mobile source (**90 HP**), each paying **120 gold**. Different
random worlds prevent a causal comparison. The mobile combat capture includes
an actual Blink near the north boundary with hero and quarry visible.

Root inspected **90 original PNGs** including baseline and partial experiments;
independent review inspected **56**, with exact attribution in the manifests.
Existing hymn hero/cast-panel overlap matches the prior checkpoint's native
capture. Hunt panels, notices and decorative labels retain their documented
overlap limits. Evidence and the resulting commit are pinned in
`build/qa/session-sept17/camera-lead-checkpoint-validation.json`.
All 46 unrelated preserved files remain unchanged.
