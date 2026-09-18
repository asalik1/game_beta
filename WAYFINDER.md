# Wayfinder — September 7, 2026

Owner: Codex. Branch: `codex/crownless-wayfinder`.
Base: `3c07384` on `claude/visual-overhaul-2026-09-03`.

## Intent

Make exploration easier to read and more satisfying without changing the combat
economy or revealing undiscovered content. The map should help a player make a
decision, and a decision should remain visible after the map closes.

## Work

- [x] Live local map: player facing, enemies, revealed chests, people and doors.
- [x] Field atlas: explored graph, room details, route selection and fast travel.
- [x] Route guidance: pins, next-door bearing, blocked-route feedback and arrival.
- [x] Encounter readout: living threats, room-clear feedback and remaining loot.
- [x] Codex field notes and regression coverage.
- [x] Desktop compile, quick/full suite; mobile compile/quick; visual review.

## Try it

Run `run_game.bat` from this worktree. Start or continue a chapter, then press
**M** (or tap the corner map). Select a passage and choose **Set route**.
**Main trail** selects the next known step toward the chapter's objective.
After closing the atlas, follow the gold doorway bearing. During combat the
corner map tracks foes; after the clear it shows any revealed chests left behind.

Drag the atlas to pan, use the wheel or **+ / −** to zoom, and use **Recenter**
to fit the chart. **Previous / Next** also select rooms using keyboard focus or
touch. Select a visited sanctuary or defeated boss arena to fast travel.

## Constraints

Presentation reads the local player's world; it never mutates combat, fog of war,
locks or save progression. Routes use charted rooms and one observed frontier.
Hidden chests stay hidden. Menus gate input in co-op as well as solo. Pins belong
to the current run/chapter and cannot survive into an unrelated layout.

## Validation

- Desktop compile gate and quick suite: **PASS**.
- Desktop full suite: **PASS**, 173 reported checks, including the campaign,
  later chapter spines, content, combat systems and UI.
- Mobile import, compile gate and quick suite: **PASS**. All changed gameplay
  scripts and the screenshot rig are byte-identical across desktop/mobile;
  platform renderer/export settings retain their existing deltas.
- Preflight: **PASS** for import cache, module registration, balance constants,
  physics connections, screenshot rigs and asset verification. The remaining
  data check passed separately: **80 enemies, 22 boss kinds**.
- `shot.bat wayfinder --no-import --timeout=240`: **PASS**, 11 captures reviewed
  in the actual renderer, covering early exploration, frontiers, route bearings,
  combat, loot, atlas zoom, touch controls, room clear and the return journey.
  The rig also asserts that a real clear is acknowledged by the live map.
- Regression coverage checks fog limits, locked/unlocked routes, disconnected
  pocket arenas, stale NPC references, actual chest registration/filtering,
  atlas route buttons, overlay hiding, chapter reset and destination arrival.
- Stabilized the existing co-op overlay probe: its control step now waits for
  a physics tick and isolates combo cooldown refunds before checking a cast.

Logs are in `build/qa/`; captures are under
`build/qa/visual-user/Godot/app_userdata/Crownless/shots/wayfinder/`.
Visual and mobile checks use isolated user-data directories. Mobile validation
is headless plus rendered touch-layout review, not an on-device build.

The passing full suite retains its existing invalid-code decode diagnostic and
bare ObjectDB shutdown warning. Windowed rigs retain the texture-RID shutdown
warnings also reproduced on the unchanged source snapshot. No script errors
occurred in the final passing runs.

## Field Atlas navigation and return hints (checkpoint 27)

Opening the Field Atlas gives keyboard users an initial focus target. Focused Atlas
buttons have a visible gold outline, scoped to the Atlas rather than the shared button
theme. Previous and Next retain keyboard focus after selecting another room, so repeated
activation keeps browsing. The return footer names the current map binding on keyboard
and the actual Back button for Xbox/PlayStation labels. Touch wording is unchanged.
Footer labels are built when the Atlas opens; this does not claim live refresh of an
already-open footer or change input routing.

The old-source focus diagnostic completes with exactly six expected findings: two
keyboard-entry observations and the four repeated-focus controls. The separate footer
diagnostic remains complete=false with 3 actual failed copy rows; it is a classified
strict rejection, not a passing baseline. Fixed focus/footer checks pass 51/65 on
desktop and 51/65 on host-rendered mobile. Quick/full checks pass 147/227; mobile quick
passes 147. All 76 original images have attributed original-resolution review. Exact
diagnostic IDs and source-bound evidence are retained in
`build/qa/session-sept17/atlas-keyboard-checkpoint-validation.json`. Final strict
preflight, source/UID preservation, commit and local-state audit remain required for
acceptance and are recorded there.

The focused fixtures freeze inherited world processing after ordinary reveal, retain
live menus/gamepad, and use temporary keyboard bindings and a synthetic controller
device. Each old-source keyboard-entry failure is recorded before an actual Recenter
mouse click seeds focus for the original repeated-activation controls. The fixed mode
forbids these seeds and requires pure keyboard entry. Same-turn reader replacement
checks deferred focus ownership. Native controls also exercise D-pad staying in the
reader and Back closing it. Touch checks cover copy/layout, not a native touch-close
gesture. Preference/focus loans are restored without settings persistence. Default
Wayfinder captures include controlled pose/fog/god-mode presentation; these are not
ordinary journeys. Existing controller disconnect coverage retains its log witness and
duplicate Settings capture limitation. Host rendering is not physical-device validation;
no new ENet transport claim is made. Existing suite ObjectDB and renderer shutdown
diagnostic policy remains in force; logs are not claimed warning-free.

