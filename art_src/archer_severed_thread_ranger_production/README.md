# Severed-Thread Ranger — Archer production source

This directory is the reproducible source of truth for the regenerated Archer
base family. The art was authored with OpenAI's built-in ImageGen, normalized
by `tools/art/build_severed_thread_archer.py`, and installed into
`game/assets/sprites`.

The approved design anchor is:

`art_src/archer_base_refinement/03_severed_thread_ranger_correct_grip.png`

The repository-wide sprite workflow and its general failure policy are in:

`tools/art/IMAGEGEN_SPRITE_PIPELINE.md`

## 1. Canonical identity

Every generation and repair must preserve all of these traits:

- adult woman with visible brown hair and a readable, non-glamourized face;
- broad, weathered forest-green cloak and grey-brown fur mantle;
- layered brown leather armor, fitted green trousers, and practical boots;
- one back quiver only;
- a snapped red oath-cord visible at the chest;
- exactly one continuous wooden recurve bow;
- exactly one taut string running from upper tip to lower tip;
- the bow hand grips the wooden riser, never the string;
- no idle arrow, floating arrow, duplicate bow, shield, staff, or extra quiver.

The silhouette should read as a wary wilderness oathbreaker rather than a
generic village hunter: broad cloak, guarded posture, asymmetrical travel wear,
and a disciplined but unceremonious bow grip.

## 2. Runtime contract

The live Archer family is exactly 83 PNG files with one shared square cell
size. The current build resolves to 287 x 287 px per frame:

| Runtime family | Frames | Direction files |
| --- | ---: | --- |
| `archer.png` | 1 | static south idle |
| `archer_anim` | 4 | base plus S, SE, E, NE, N, NW, W, SW |
| `archer_walk` | 6 | base plus eight directions |
| `archer_run` | 6 | base plus eight directions |
| `archer_attack` | 9 | base plus eight directions |
| `archer_attack2` | 9 | base plus eight directions |
| `archer_cast` | 9 | base plus eight directions |
| `archer_dash` | 6 | base plus eight directions |
| `archer_ult` | 9 | base plus eight directions |
| `archer_ultidle` | 5 | base plus eight directions |
| `archer_death` | 9 | base/south only |

The Archer ability mapping in game is:

- ability 1: `attack`;
- ability 2: `attack2`;
- ability 3: `dash`;
- ultimate cast: `cast`.

`ult` and `ultidle` remain loader-compatible runtime families even though the
current Archer ability mapping does not call them directly.

South, south-east, east, north-east, and north are authored. North-west, west,
and south-west are deterministic horizontal mirrors of NE, E, and SE. This is
intentional: it guarantees that NE/NW and E/W cannot be accidentally inverted.

## 3. ImageGen authoring specification

Start from the approved anchor image, not from an already assembled runtime
sheet. Use a flat, saturated green generation field because ImageGen is more
reliable at separating detailed dark fantasy figures from green than from
transparency. Never describe the green as clothing or scenery.

Use this identity block in every prompt:

> Same Severed-Thread Ranger woman as the supplied reference: visible brown
> hair, weathered forest-green broad cloak, grey-brown fur mantle, layered
> brown leather armor, green trousers, boots, one back quiver, snapped red
> oath-cord. Exactly one continuous wooden recurve bow and exactly one taut
> tip-to-tip string. Her bow hand grips the wooden riser, never the string.
> Preserve her face, proportions, costume, palette, equipment count, and
> painterly high-resolution dark-fantasy game-sprite rendering exactly.

Then add one clip-specific block:

- **Rotation:** five isolated full-body poses ordered S, SE, E, NE, N. Same
  neutral stance and baseline in every cell. No animation.
- **Idle:** five rows ordered S, E, NE, SE, N with four restrained breathing
  phases per row. Feet stay planted; cloak/fur and shoulders move subtly.
- **Walk:** six frames for one direction. Frames 1 and 4 are opposite contact
  poses; frames 2 and 5 are opposite passing poses; frames 3 and 6 are opposite
  recoil/high points. Alternate legs clearly without high knees, locked elbows,
  heel-clicking, or a military march. The bow remains lowered and unchanged.
- **Run:** six frames with stronger forward lean, longer grounded stride, and
  cloak drag. Preserve left/right leg alternation and avoid a walk-speed march.
- **Attack:** nine-frame deliberate bow shot: settle, nock, raise, draw,
  full-draw hold, release, follow-through, recoil, recovery. The string must
  remain attached to both tips. A single arrow may exist only as part of the
  shot.
- **Attack 2:** nine-frame faster evasive shot with a distinct lower-body
  action and recoil, not a copy of `attack`.
- **Dash:** six-frame compact combat tumble/evade. The Ranger keeps the bow;
  it never vanishes, duplicates, or changes handedness.
- **Cast:** nine-frame Arrow Storm invocation: gather, aim upward, release, and
  recover. Effects may rise away from the character, but the base bow anatomy
  stays readable.
- **Ultimate:** nine-frame stronger marked-arrow release with a clear
  anticipation, release, follow-through, and recovery.
- **Death:** nine-frame one-way collapse from standing to a final grounded
  body. No resurrection, loop-back, or facing flip. The bow falls beside her
  and remains present in the final frame.

For a strip, explicitly request a single straight row, exact frame count,
equal-size cells, generous empty gutters, common ground line, complete figure
and equipment inside every cell, no labels, no UI, and no crop. Generate only
one direction or one tightly specified row set at a time. Reject a strip before
processing if its frame count, direction, equipment, or gait is wrong.

## 4. Accepted masters and repairs

| Runtime use | Accepted ImageGen master |
| --- | --- |
| rotation gate | `regen_base_rotations_v01_keyed.png` |
| idle | `regen_idle_v01_keyed_rows_s_e_ne_se_n.png` |
| walk S / SE / E / NE / N | `regen_walk_s_v01_keyed.png`, `regen_walk_se_v01_keyed.png`, `regen_walk_e_v02_keyed.png`, `regen_walk_ne_v01_keyed.png`, `regen_walk_n_v01_keyed.png` |
| run S / SE / E / NE / N | the five `regen_run_*_v02_keyed.png` files |
| attack S | `regen_attack_s_v02_keyed_f9_replace_f1.png` |
| attack SE | `regen_attack_se_v02_keyed.png` |
| attack E | `regen_attack_e_v03_keyed.png` |
| attack NE | `regen_attack_ne_v03_keyed_needs_f7_repair.png` plus `regen_attack_ne_f7_release_repair_v01_keyed.png` |
| attack N | `regen_attack_n_v02_keyed_f7_replace_f6.png` plus `regen_attack_n_f7_release_repair_v01_keyed.png` |
| attack2 S / SE / E / N | `regen_attack2_s_v01_keyed.png`, `regen_attack2_se_v02_keyed.png`, `regen_attack2_e_v01_keyed.png`, `regen_attack2_n_v01_keyed.png` |
| attack2 NE | `regen_attack2_ne_v01_keyed_needs_f8_repair.png` plus `regen_attack2_ne_f8_recoil_repair_v01_keyed.png` |
| dash S / SE / E / NE / N | the five `regen_dash_*_v01_keyed.png` files |
| cast S / SE / E / NE / N | the five `regen_cast_*_v01_keyed.png` files |
| ultimate S / SE / E / N | the corresponding `regen_ult_*_v01_keyed*.png` files |
| ultimate NE | `regen_ult_ne_v01_keyed_needs_f8_repair.png` plus `regen_ult_ne_f8_release_repair_v01_keyed.png` |
| death | `regen_death_s_v01_keyed.png` |

Repairs are independently generated single poses scaled to the local strip;
they are not duplicated neighboring action frames. Two loop bookends are
deliberate exceptions:

- south `attack` frame 9 uses frame 1 as the final recovery pose;
- south `ult` frame 9 uses frame 1 as the final recovery pose.

These are end-of-action recoveries only. Never hide a broken release or
follow-through by copying an adjacent middle frame. `ultidle` is derived
deterministically from accepted idle phases `[1, 2, 3, 4, 2]` because it is an
unmapped loader-compatibility family.

## 5. Rejected masters and why

Rejected files are retained as failure examples and must not be wired:

- `regen_walk_e_v01_rejected_nonalternating.png`: feet did not alternate;
- `regen_run_v01_rejected_5cols_crop.png`: wrong column count/cropped content;
- `regen_run_se_v01_rejected_nonalternating.png`: nonalternating gait;
- `regen_attack_v01_rejected_4rows_arrow_only_frame.png`: wrong layout and an
  arrow-only frame instead of a complete character;
- `regen_attack_se_v01_rejected_frontal.png`: facing drifted to frontal;
- `regen_attack2_se_v01_rejected_frontal.png`: facing drifted to frontal;
- `regen_attack_e_v02_keyed_endpoints_from_idle.png`: endpoint substitution was
  visible; E was fully regenerated as v03;
- `regen_attack_ne_v02_keyed_f7_replace_f6.png`: an adjacent mid-action
  duplicate; replaced by v03 plus a separately authored release repair.

Filename notes such as `needs_f7_repair` document source defects. The builder
contains the authoritative final frame mapping.

## 6. Deterministic build

Run from the repository root with the bundled Pillow/NumPy Python:

```powershell
& 'C:\Users\asali\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/art/build_severed_thread_archer.py
```

The builder performs these operations in order:

1. hard-keys saturated green while protecting the Ranger's darker cloak;
2. recolors dim, strongly green-dominant cord remnants to shaded tan rather
   than deleting them;
3. finds low-occupancy gutters near nominal grid boundaries and slices cells;
4. installs the three explicitly authored single-pose repairs;
5. scales each direction/clip to a 180 px standing-body reference and a shared
   staging baseline;
6. applies a second thin-component green correction after LANCZOS resize,
   because resampling can mix a keyed fringe back into one-pixel string detail;
7. hardens alpha to 0 or 255;
8. mirrors W, SW, and NW from E, SE, and NE;
9. computes one union crop and assembles all 83 files at a shared cell size;
10. validates file count, dimensions, frame count, nonempty cells, and absence
    of semitransparent pixels.

The post-resize cord correction uses color dominance plus a 5 x 5 occupancy
guard. Broad cloak regions are not selected; narrow bow/string pixels retain
their alpha and position and merely change from key green to muted tan/brown.
The audited NW frames are shown in:

`qa/archer_walk_nw_f2_f4_string_before_after_4x.png`

## 7. QA generation and review gates

Generate all eight-direction contact sheets:

```powershell
& 'C:\Users\asali\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' tools/art/anim_sheet.py archer all art_src/archer_severed_thread_ranger_production/qa 2
```

The `qa` directory contains contacts for every family, eight-direction GIFs,
the authored walk gate, the death contact/GIF, and the cord correction zoom.

Review at native size and enlarged pixel size. Required visual gates:

- same woman, costume, bow, quiver, hand, and baseline across every frame;
- no NE/NW or E/W inversion;
- clear opposite-foot contacts in walk and run, with no march;
- no facing flip on the final action frame;
- one continuous wooden stave and a legible tip-to-tip string;
- no green key residue, duplicate equipment, missing bow, or arrow-only cell;
- no adjacent duplicated middle action frames;
- death moves in one direction only and retains the fallen bow.

## 8. Archive and rollback

The exact 83-file runtime family that preceded this regeneration is preserved
at:

`archive_original_runtime_2026-07-31`

`SHA256SUMS.txt` records every archived file. Before changing or restoring the
archive, verify all 83 hashes. The archive is source history only and must not
be imported or wired as live game art.

## 9. Verification sequence

After any accepted source or builder change:

1. rebuild the 83 runtime files;
2. refresh and visually inspect all contacts/GIFs;
3. run the Godot headless import;
4. run `verify_art.py archer`;
5. run the compile gate;
6. run `test_quick.bat`.

Do not proceed to another class when any equipment, gait, facing, keying,
geometry, import, compile, or quick-test issue remains.

### Accepted production audit — 2026-07-31

- archive: 83 manifest entries, 83 archived PNGs, 0 SHA-256 mismatches;
- live inventory: exactly 83 Archer PNGs;
- builder validation: all expected frame counts and 287 px shared-cell
  geometry pass; no empty frames or semitransparent pixels;
- visual QA: all clip contacts pass; NW walk frames 2-4 specifically pass the
  tan-cord/no-green-spill gate;
- Godot headless import: pass, all 83 Archer files reimported;
- `tools/art/verify_art.py archer`: `VERIFY OK`;
- compile gate: `COMPILE OK (97 scripts)`;
- `test_quick.bat`: `AUTOTEST QUICK PASS`.

The quick suite printed its existing shutdown RID/ObjectDB leak warnings after
the explicit pass marker; the verdict script returned success. No Archer
import, geometry, compile, or gameplay-test failure remained.
