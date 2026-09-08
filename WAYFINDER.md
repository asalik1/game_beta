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
