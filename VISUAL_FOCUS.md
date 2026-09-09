# Visual focus

Pass 32 makes the graveyard floor quieter, gives Vigil Gate two modest gathering points, and frees more of the playfield from the hero dossier. Existing painterly art, combat controls, NPC services, quests and story gates remain the reference. This note records the validated implementation and the limits of its evidence.

## Current behavior

**Graveyard earth.** Gravedirt uses `game/assets/sprites/ground_field_gravedirt_painterly.png`: the full **1254×1254** generated master, repeated every **512 world units**, with mipmaps and the existing ground-field renderer. The quieter packed-earth pattern reduces repeated grass ticks and cracks without a blur, downscale, recolor or broad darkening pass. Roads, boundary detail and room lighting retain their existing paths. Stone is the unchanged comparison material.

The installed PNG is byte-identical to `art_src/ground_focus_2026-09-09/packed_earth_v1.png`, SHA-256 `d0172428722dd2e305942c61e13175942a11fe5b586587eaf77117acc6caee3d`. The exact image-generation prompt is preserved in `art_src/ground_focus_2026-09-09/prompt.txt`; `provenance.json` beside it records the built-in image_gen output, reference images and source path. Native material review is in `build/qa/grave-earth-v1-visual-review.md`.

**Vigil Gate.** Four authored furnishings—two existing benches, garden urns and an amphora—give Ilse and Fenna low gathering points. Reduced random scatter keeps the center and exit approach open. At the comparison seed **903126**, Vigil drops from **97 to 58 scenery roots** and **24 to 18 scenery obstacle bodies**; these are measured seed-specific counts, not a promise for every generated layout. NPC positions, identities, dialogue, reach, quests, rewards and gate conditions are unchanged. The authored provision coordinate does not add a shop. Changes live in `game/scripts/content/ch3_zones.gd`.

**Small ground stones.** The logical static `pebble` prop reuses the existing angular `rock2` texture at its existing **24-world-pixel** authored width. Placement, clumping, variation and noncolliding ground-decor behavior continue to use the logical pebble identity. The fallback is local to `Game._prop_visual` in `game/scripts/game_world.gd`; `Art` and the original pebble asset are unchanged, including direct consumers outside ground scenery. Both renderer checks pass in five settled terrain palettes.

**Hero dossier.** `game/scripts/hud.gd` reduces the panel from **344×148 to 344×104** at the same origin: about **30% less backdrop area**. Two bounded information rows sit above seven fixed **44×44** utility targets; Party has a reserved **44×44** header target. Hiding Daily or changing party state leaves the other controls stationary. The existing level badge replaces duplicate level text; potion availability remains on the actual action button and inventory. Vital and action-control geometry stays unchanged.

The full **70×70 portrait** and identity text open hero details by mouse or touch, including the full name, class, earned title, level, skill points, gold, combat rating and resonance explanations. Gold also opens its own detail. Skills retains a numeric point badge, hidden at zero. Signed negative resonance uses readable pale text and an outline. Native font measurements preserve exact tested high values, with full values also reachable in details. Badges follow their controls; party rows and the DPS meter follow the panel bottom.

## Validation

Paths are relative to the repository root. Each completed run has matching `-user/Godot/app_userdata/Crownless/shots/<rig>/` images and an `observations.json`; HUD images use the `desktop/` or `touch/` child directory.

| Evidence | Recorded result | Log / review |
| --- | --- | --- |
| Desktop original world | 68 checks, 0 failures, 9 native frames | `build/qa/visual-focus-desktop-baseline1.log` |
| Desktop earth only | 68 / 0 / 9 frames | `build/qa/visual-focus-desktop-earth1.log` |
| Desktop earth + composition | 68 / 0 / 9 frames | `build/qa/visual-focus-desktop-composition1.log` |
| Mobile-source original world | 68 / 0 / 9 frames | `build/qa/visual-focus-mobile-baseline1.log` |
| Mobile-source earth only | 68 / 0 / 9 frames | `build/qa/visual-focus-mobile-earth1.log` |
| Final combined world, desktop and mobile-source | **68 checks, 0 failures, 9 frames each** | `build/qa/visual-focus-desktop-final1.log`, `visual-focus-mobile-final1.log` |
| Desktop compact HUD, actual mouse inputs | **503 checks, 0 failures, 0 findings, 22 frames** | `build/qa/hud-dossier-desktop-compact2.log` |
| Mobile-source compact HUD, actual ScreenTouch events | **503 / 0 / 0 findings / 22 frames** | `build/qa/hud-dossier-mobile-compact2.log` |
| Desktop Vigil ordinary movement / E interactions | **49 checks, 0 failures, 31 continuous walk legs, 12 frames** | `build/qa/vigil-walk-desktop-gathering1.log` |
| Mobile-source Vigil ordinary keyboard / E interactions | **49 checks, 0 failures, 31 continuous walk legs, 12 frames** | `build/qa/vigil-walk-mobile-gathering1.log` |
| Final pebble tint and reuse regression, both renderers | **258 checks, 0 failures, 7 frames each** | `build/qa/pebble-prop-desktop2.log`, `pebble-prop-mobile2.log` |
| Ordinary warrior combat on the installed earth | **Won, normal starting health, 5 frames** | `build/qa/grave-earth-combat-warrior1.log` |
| Mage combat with a six-second attack delay | **Failed: hero died; 6 frames preserved** | `build/qa/grave-earth-combat-mage1.log` |
| Ordinary mage combat, standard attack timing | **Won, normal starting health, 4 frames** | `build/qa/grave-earth-combat-mage-standard1.log` |
| Ordinary HUD body overlap / clearance | **Desktop and mobile passed, 12 frames each** | `build/qa/hud-clearance-compact-desktop2.log`, `hud-clearance-compact-mobile2.log` |
| Installed material/import/color/Codex rendering, both renderers | **Passed, 6 frames each** | `build/qa/grave-earth-installed-floorfield-desktop1.log`, `grave-earth-installed-floorfield-mobile1.log` |
| Final desktop compile and quick suite | **Compile224 / 125 checks, passed** | `build/qa/checkpoint32-desktop-quick4.log` |
| Final desktop compile and full suite | **Compile224 / 205 checks, passed** | `build/qa/checkpoint32-desktop-full2.log` |
| Final mobile import / compile / strict quick | **Passed / compile224 / 125 checks** | `build/qa/checkpoint32-mobile-import.log`, `checkpoint32-mobile-compile.log`, `checkpoint32-mobile-quick.log` |
| Source parity | **21 exact pairs, 5 independent UID pairs** | `build/qa/checkpoint32-mirrors.json`; 53-source-file freeze |
| Full preflight | **Passed, no findings** | `build/qa/checkpoint32-preflight.log` |

All **44 final HUD images** were reviewed in `build/qa/hud-dossier-final-native-review.md`: all 13 input openings work in each run, portrait/identity/gold popovers fit, the full title and exact `987654321` gold / `CR 991810` / `-100` resonance remain readable, and point badges and slots retain their intended states. Reviewed HUD SHA-256: `8623071cf405465554ef44f00fb43eb12ffd0d52b06a2c927dc8f613771cd0ea`; validation rig: `cde368e14e26baa87fe32ae7d670c52512f97e3fc83229ee8e73c12454d2dbf6`.

World and desktop walk review: `build/qa/visual32-desktop-review.md`; mobile earth review: `build/qa/visual-focus-mobile-earth-review.md`; final desktop world review: `build/qa/visual-focus-desktop-final-review.md`; mobile walk review: `build/qa/vigil-walk-mobile-review.md`. All 24 clearance images were reviewed in `build/qa/hud-clearance-compact-native-review.md`. World comparisons are posed actual chapter-3 scenes at normal **1.12 zoom**, with setup teleports and frozen actors; warm samples do not establish combat or GPU performance. The desktop and mobile-source walks instead use ordinary keyboard movement after one explicit setup placement, with god mode off, real NPC prompts/E delivery and the still-blocked story exit. Mobile evidence runs the mobile source under Compatibility on the host, **not a physical device**. HUD ScreenTouch evidence does not establish touch combat; seeded party shells do not establish real peer replication. No completed row certifies a later tint or source revision.

Combat review: `build/qa/grave-earth-combat-review.md`. The normal hunt retains Village Outskirts lighting and mechanics while transplanting only the installed floor into its existing polygon. It does not certify chapter-3 combat. The delayed-attack mage loss remains a failed win check; visible spell/windup captures do not turn it into a pass. No balance or input-controller changes were made for this visual pass.

Installed import review: `build/qa/grave-earth-installed-floorfield-review.md`. All 12 frames were inspected; mipmaps and midtone/near-black screenshot calibration passed. The preview API returned a texture for graveyard, while the actual opened Codex screenshot selected Emberfall Village. This does not claim a selected graveyard-detail visual check.

The first full suite failed the outgoing identity-line assertion; source review also found the old conditional-button reflow expectation. The updated contract checks retained name/class, full title/level/skill-point details and fixed, separate 44px targets. An explicit visible-Daily/hidden-Party state precedes the opposite visibility state, and all borrowed identity and visibility state is restored before reporting failure. The initial runs also exposed an older freed-node callback diagnostic from the shadow lifetime test. `PropShadow` now uses a distinct callback holding weak references and resolves them at dispatch; normal drawing and transforms are unchanged. The lifetime test retains the retired-shadow case and verifies both retained signal paths plus a replacement shadow's next frame. Its new replacement check rejected the first static-bound callback candidate, which Godot treated as a duplicate signal connection. The suite verdict now also rejects the original freed-capture diagnostic. Four log fixtures validate that rule while retaining the intentional invalid-base64 negative control; exact expected/actual exits are in `build/qa/suite-verdict-lambda-fixtures/results.json`.

The gate history is retained under `build/qa/`:

- `checkpoint32-desktop-quick.log` printed the quick pass marker but contained the freed-capture error; it is not a clean final acceptance run.
- `checkpoint32-desktop-full.log` failed the obsolete identity assertion and also contains that error.
- `checkpoint32-desktop-quick2.log` failed the replacement-frame assertion and reported duplicate signal connections.
- `checkpoint32-desktop-quick3.log` stopped at the compile gate on inferred Variant warnings in the weak-reference closure; it did not run the suite.
- After explicit typing, `checkpoint32-desktop-quick4.log` passed compile224 and 125 checks, and `checkpoint32-desktop-full2.log` passed compile224 and 205 checks. Neither contains the freed-capture diagnostic or a script/parse error. Full2 retains the intentional invalid-base64 negative-control error and bare ObjectDB exit warning; this is not a clean-stderr claim.

Final mobile import, compile224 and strict quick125 passed. Source parity has 21 exact pairs and five independent UID pairs; full preflight passed without findings. Checkpoint identity and exact paths are recorded in `build/qa/checkpoint32-validation.json`; the separate torch-placement and dialogue-reader candidates await their own baselines.

## Reproduction

Use a fresh isolated QA `APPDATA` under `build/qa`, preserve its previous value and restore it afterward. Run serially through the muted, compile-gated runner; do not run alongside image generation or another engine. From the repository root:

```text
shot.bat visual_focus --timeout=300 --label=current
shot.bat hud_dossier --timeout=300
shot.bat vigil_walk --timeout=300 --label=gathering --expect-gathering
```

For host mobile-source world/HUD runs, append `--mobile --renderer=gl_compatibility --touch`. For the keyboard/E mobile-source walk, append only `--mobile --renderer=gl_compatibility`. Use separate QA homes per run. Captures and JSON receipts are part of the verdict; inspect native frames as well as the runner result. Baseline/material/composition comparisons require their recorded source revisions and fixed seed, not merely changing the run label.
