# Class Sprite Corrective Pass — Orientation, Stride, and Quality Audit

Date: 2026-07-31

Status: lossless-cut V3 walk families are installed in desktop and mobile. Automated art, quick-gameplay, full-campaign, and mobile gates pass; final hands-on movement QA remains open.

## Confirmed root cause and corrective rule

The rejected pass had three source-to-runtime cutting defects: nominal equal-height cuts crossed irregular ImageGen rows, component cleanup deleted valid disconnected cloth/props, and some inferred valleys still contained visible pixels. This produced flat-cut Mage heads, incomplete Assassin capes, misassigned neighboring fragments, and unsafe Warlock diagonal cells even when the master contained usable art.

The V3 builder now accepts a boundary only inside a broad contiguous transparent gutter, asserts zero separator occupancy, preserves every keyed source pixel through rectangular partitioning, and emits a source-resolution cut overlay. Warrior, Mage, Archer, and Assassin use independently authored direction strips. Warlock preserves the approved cardinal runtime pixels and replaces only the four unsafe diagonals. Assassin Fan of Knives uses audited pose-centered assignment because its legacy six-pose masters are irregular; it no longer applies brightness/main-blob cleanup that removed dark cape panels.

## Binding runtime convention

- `S`: front view, moving down-screen.
- `SE`: front-right three-quarter view, moving down and right.
- `E`: right-facing profile, moving right.
- `NE`: rear-right three-quarter view, moving up and right.
- `N`: back view, moving up-screen.
- `NW`, `W`, and `SW` are the corresponding left-facing views.
- Source filenames, prompt labels, sheet row order, and generator output order are untrusted metadata. A human/visual audit assigns every source row by the direction the body actually faces.
- The engine mapping is already correct: it selects suffixes from velocity and does not flip the hero sprite. Direction defects belong in the source-to-runtime art mapping.

## Mandatory walk-cycle gate

Every direction must show two distinct opposing contacts in one loop:

1. left-leg contact: left foot clearly leads and is planted;
2. left load/passing transition;
3. center/passing pose;
4. right-leg contact: right foot clearly leads and is planted;
5. right load/passing transition;
6. center/passing pose returning toward frame 1.

Seven- or eight-frame contracts may add in-betweens, but may not replace either opposing contact. The torso stays relaxed with modest counter-swing; this is a normal walk, not a high-knee march. A strip fails if robes, cloak, or a weapon hide both leg contacts so completely that alternation is unreadable at runtime size.

## Equipment and anatomy invariants

- Warrior: closed restraint helmet, ember sword always present, anatomical-left arm exposed, opposite arm fully armored. No frame may turn the exposed arm into plate or expose the wrong arm.
- Warlock: hooded Ledgerbound Debtor, closed ledger carried at the hip, hands free in locomotion, no unexplained button/object in either palm.
- Mage: staff remains in the same hand and never changes sides inside a direction strip.
- Archer: hand grips the bow body, never the string; bow, string, and quiver remain complete.
- Assassin: hooded void face, single long blade and sheath/knife inventory remain consistent.

## Quality benchmark

Maren (`elder.png`) and the approved Oathbound Arbiter Paladin define the readability bar. Review at the actual rendered body height first, then magnify with nearest-neighbour scaling. Passing art needs:

- a clean silhouette and broad material groups readable at about 88 screen pixels;
- deliberate pixel clusters instead of downsampled texture noise;
- distinct light/mid/dark masses, especially between coat, limbs, and equipment;
- stable face/helmet, garment construction, handedness, and prop geometry across frames;
- no extra blur introduced by repeated resizing.

## Corrective result

| Class | Observed-facing sort | Two-step stride | Identity/equipment | Runtime-size clarity | Runtime status |
| --- | --- | --- | --- | --- | --- |
| Warrior | Pass: all eight rows assigned from visible facing | Pass: opposing contacts highlighted at f1/f4 | Pass in proof sheet: anatomical-left arm exposed when visible; opposite arm armored; sword and helmet stable | Re-anchored with cleaner material groups | Installed |
| Warlock | Pass: approved cardinals retained; four diagonals regenerated and sorted by observed facing | Pass: opposing contacts highlighted at f1/f4 | Pass: closed ledger at hip; hands clear; hood and coat stable | Cardinal pixels preserved; diagonals rebuilt from clean high-resolution masters | Installed |
| Mage | Pass: the original inversion was rejected and rows were routed by observed facing | Pass: opposing contacts highlighted at f1/f5 | Pass: one staff, stable hand and garment construction | Approved design retained with cleaner walk sources | Installed |
| Archer | Pass: all eight standalone strips assigned by observed facing | Pass: opposing contacts highlighted at f1/f5 | Pass: hand grips bow body; full bow/string/quiver | Approved design retained; every direction uses a safely separated standalone strip | Installed |
| Assassin | Pass: all eight standalone strips assigned from visible facing | Pass: opposing contacts highlighted at f1/f5 | Pass: void hood, red sash, full cape, and single long blade stable | Fresh high-resolution walk masters; cape/hood/sword clear every cut | Installed |

## Installation evidence

- The immediately prior runtime walks are preserved under `rejected_runtime_walks/pre_lossless_v3_2026-07-31/`; the earlier archive under `pre_corrective_2026-07-31/` is also retained.
- V3 sources live under `walk_v3_sources/`, QA contacts and cut overlays under `qa_v3/`, and unwired candidates under `<class>_walk_v3_candidate/`. The deterministic build/install steps are `tools/art/build_walk_v3_candidates.py` and `tools/art/install_corrective_class_walks.py`.
- The prior Assassin knife-throw strips are preserved under `art_src/assassin_erased_name/archive/pre_lossless_attack2_recut_2026-07-31/`.
- Installation pads corrected pixels into each class's existing shared runtime cell without rescaling them. This preserves the family baseline and prevents clip-to-clip scale jumps.
- Godot `--import`: pass for all 45 replaced walk PNGs.
- `verify_art.py warrior warlock mage archer assassin`: pass.
- `test_quick.bat`: `AUTOTEST QUICK PASS` (97 scripts compiled).
- `test.bat`: `AUTOTEST PASS` (full desktop campaign suite).
- `tools/sync_mobile.py --apply --gate`: 45 walk PNGs plus 9 Assassin knife-throw PNGs synchronized; mobile compile/quick gate passed.
- Final mobile drift check: 13,569 files checked, zero drift and zero unexpected mobile-only files.
- The quality claim in this audit applies to the corrected walk clips. Other clip families must be judged separately rather than inheriting a pass from locomotion.

## Wiring gate

A candidate can be installed only after all of the following are present and reviewed:

1. a direction contact sheet labeled by **observed** facing;
2. a per-direction animated GIF at gameplay timing;
3. a stride-phase sheet that identifies the left and right contact frames;
4. an equipment-invariant check across every frame;
5. a same-scale comparison beside Maren and Paladin;
6. a runtime movement test in all eight directions.

Items 1-5 are complete for the installed walks. Item 6 is the user's hands-on QA pass.
