# Crownless — visual clarity and gameplay QA

Continuing the autonomous work on `codex/crownless-wayfinder`.

## Findings and work

- [x] Make ground-attack timing legible on bright and dark terrain, and verify
  that warnings and damage share pause, recovery and chapter lifetimes.
- [x] Reveal the current combat target behind foreground foliage without
  changing scenery placement, collision, or hiding entire buildings.
- [x] Prevent simultaneous announcement plaques from covering the play area.
- [x] Compare a painterly keep floor in-game, retaining the full master and
  matching the material's world scale and exposure.
- [x] Review motion and representative environments in the real renderer.
- [x] Complete desktop/mobile regression checks, preflight and staging.

Baseline: `shot.bat polish --no-import --rooms=2,17,20 --zoom=1.0 --hud
--timeout=240` passed, with 13 captures. Darkwood's foreground trees obscure
several enemies; simultaneous room/reward plaques compete with the world view.
Ground attacks used pause-independent timers while their tweens paused with the
world. A real 12-damage attack reproduced health loss during pause before the
fix; the same check now proves damage waits until the player resumes.

Authored character/prop assets remain the visual foundation. This pass focuses
on composition, readable combat and consistency during actual play.

## Implemented

- Fixed-boundary ground markers add a clockwise timing rim and dark edge for
  contrast on bright terrain. Shelters have inward chevrons; decoys still
  flicker. These indicators do not change damage areas or balance.
- Pending ground attacks own their warning, falling art and shelter nodes.
  Their clocks pause together; a death reset or chapter rebuild cancels the
  old encounter's delayed damage and visuals. Guest mirrors remain visual-only.
- The current target is revealed through trees whose actual painted pixels
  cover its head/body. Original alpha returns when the target moves away or
  the setting is disabled. Collision and buildings retain their behavior.
- Announcement plaques serialize, deduplicate and wait behind menus, dialogue
  and arrival titles. Their reading time resumes after the overlay closes.
- The keep uses a painterly stone master with a 384-world-pixel repeat period,
  mipmaps and a field-only exposure adjustment. The codex preview matches it.
  See [asset provenance and exact prompt](art_src/ground_fields_2026-09-07/README.md).
- The existing motion rig now accepts `--beats=forest,keep,forest_hud,road,magma,keep_wall`
  so a slow renderer can capture selected sequences within its watchdog.

## Verification

- Desktop full suite: **PASS**, 175 reported checks, including the new
  pause/cancellation/guest-effect/foliage contracts. Log:
  `build/qa/quality-full-final.log`.
- Mobile import, compile gate and strict quick-suite verdict: **PASS**, 94
  reported checks. Logs: `quality-mobile-final.log`, `quality-mobile-suite.log`
  and `quality-mobile-import.log` under `build/qa/`.
- Scoped desktop/mobile parity: **PASS**, 17 source/assets files identical
  apart from the projects' independently generated script UIDs.
- Preflight: **0 failures**, six structural warnings (protocol bit packing and
  epsilon guards). Content audit: **DATA OK**, 80 enemies and 22 boss kinds.
  Logs: `quality-preflight-final.log` and `quality-preflight-data.log`.
- No script/parse errors in the final desktop or mobile suites. The desktop
  negative Base64-input diagnostic and bare ObjectDB shutdown warning are the
  existing expected suite output, accepted by its strict verdict helper.
- Changes are staged on `codex/crownless-wayfinder`; no commit was created.
  The original worktree remains untouched. Run this worktree's `run_game.bat`
  to play the integrated improvements.

`shot.bat quality --no-import --timeout=240` passed with 16 captures: floor
before/after; early/late warnings on keep, ice, magma and darkwood; foliage
before/after; announcement queue/resume; arrival composition; touch comfort.
It also exercises real paused damage and chapter rebuilding. Final log:
`build/qa/quality-visual-final.log`.

Motion was captured at 30 fps and sampled across approach, swing, whirlwind,
dash, road movement, lava pools and the keep's north gate. Two bounded runs
completed: `quality-combat-repro.log` (forest, keep, forest/HUD and road; 585
frames) and `quality-magma-repro.log` (magma and keep-wall; 240 frames). The
motion rig saves frame series directly, so its ordinary still counter reports
zero; the folders contain 825 frames. A 30 fps keep-fight preview is saved at
`build/qa/quality-keep-motion.mp4`.

Known limitation: the initial six-beat capture reached its outer watchdog
after 481 seconds and reported negative animation-frame indices. Neither
bounded rerun reproduced that error. Hero/enemy animation-clock checks now
run during capture to make a recurrence easier to diagnose; this intermittent
error is not claimed fixed. The usual renderer shutdown texture/RID warnings
also remain, matching the untouched-source baseline.

Follow-up: [COMBAT_FRAMING.md](COMBAT_FRAMING.md) records a reproducible frame-error
failure path, a naturally recurring physics fault, and the subsequent top-down
movement / zero-time hit-stop fixes and regression results.
