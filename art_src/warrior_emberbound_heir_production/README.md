# Emberbound Heir Warrior — production source

**Status:** regenerated and wired on 2026-07-31 from the owner-approved
`art_src/warrior_base_redesign/03_emberbound_heir_restrained_helm.png`.

## Runtime contract

- Base name: `warrior`
- Static: `warrior.png`
- Eight directions (`s,se,e,ne,n,nw,w,sw`):
  - `anim` 4 frames
  - `walk` 6 frames
  - `run` 6 frames
  - `attack` 7 frames — Cleave
  - `dash` 7 frames — armored shoulder charge
  - `attack2` 7 frames — Whirlwind
  - `ult` 7 frames — Berserk activation
  - `ultidle` 4 frames
- Directionless `death`: 9 frames
- W/SW/NW are deterministic per-frame mirrors of E/SE/NE.
- Builder: `tools/art/build_emberbound_warrior.py`
- QA: `qa/` contains labeled contact sheets, eight-direction motion GIFs,
  the directionless death contact sheet, and the death GIF.

## Binding identity contract

- Broad mature player-hero proportions.
- Fully enclosed battered black-iron restraint helmet.
- Narrow sight slit stays completely unlit; no face, eyes, horns, crown,
  plume, spikes, or skull.
- Asymmetric half-plate: anatomical right side armored; anatomical left upper
  arm exposed, muscular, and scarred.
- Exactly one huge black-iron greatsword, owned by the armored right hand.
- Exactly one orange Ember fuller.
- Exactly three black restraint staple bands across the lower blade, separate
  from the crossguard.
- Chiseled blank chest scar; short split battle skirt.
- No shield, hammer, chain, seal, Paladin silver/gold/judicial-blue language,
  extra weapon, or all-over molten cracks.

## Built-in ImageGen prompt log

All generations used the built-in ImageGen tool and a flat `#00ff00` chroma
background. Every prompt repeated the identity contract above plus the
Crownless low top-down orthographic/isometric camera, premium deliberate
pixel clusters, stable ground baseline, generous gutters, no floor/shadow,
no text, no crop, and no overlap.

### Rotation gate

- `rotation_v01_keyed.png`: five views S/SE/E/NE/N. Rejected because restraint
  count and visor pinpoints varied.
- `rotation_v02_keyed.png`: precise edit making every sight slit black and
  requiring three blade staples separate from the guard. Approved S/SE/E/NE.
- `rotation_n_repair_v01_keyed.png`: exact N/back replacement with complete
  sword beside the armored right hand and all three staples visible. Approved.

No animation generation began until the combined five-view gate passed.

### Idle and locomotion

- `idle_v01_keyed.png`: 5x4 restrained breathing sheet. E and N concealed the
  sword, so their entire rows were replaced.
- `idle_e_repair_v01_keyed.png`: true E profile, four planted breathing frames,
  complete sword in every frame.
- `idle_n_repair_v01_keyed_5source.png`: N/back four-frame idle plus disposable
  fifth safety pose; builder selects the first four.
- `walk_s_v01_keyed.png`, `walk_se_v01_keyed.png`,
  `walk_e_v02_keyed.png`, `walk_ne_v01_keyed.png`: direction-specific
  six-frame natural two-step loops. Prompts specify opposite contact phases at
  f1/f4, opposite passing phases at f2/f5, low knees, heel/toe roll, subtle
  bob, planted feet, and explicit negatives for march/parade/run/shuffle.
- `walk_e_v01_rejected_crop.png`: rejected because far-right sword was cropped.
- `walk_n_v01_rejected_crop.png`, `walk_n_v02_rejected_crop.png`: rejected
  because the final sword touched/crossed the source edge.
- `walk_n_v03_keyed_7source.png`: seven semantic figures with a disposable
  trailing pose; builder selects the first six complete alternating steps.
- `run_v01_keyed.png`: 5x6 compact heavy run with opposite foot strikes,
  stronger lean/stride than walk, and stable trailing sword.

### Combat and state clips

- `attack_v01_keyed.png`: 5x7 Cleave — low guard, two-hand set, windup,
  committed slash, follow-through, and recovery.
- `attack2_v01_keyed.png`: 5x7 Whirlwind — coil, grounded sweep, braking, and
  explicit final-facing recovery.
- `dash_v01_keyed.png`: 5x7 armored-right shoulder charge with the sword
  trailing; explicitly no shield.
- `ult_v01_keyed_8source.png`: requested seven-frame Berserk activation but
  ImageGen supplied eight semantic columns. Builder drops redundant source
  column 4 and keeps the pressure peak/recovery. Rear rows use the approved
  complete guard sequence because the combined master hid the low blade;
  gameplay FX carries the rear-facing power surge without breaking equipment.
- `ultidle_v01_keyed.png`: 5x4 restrained empowered idle. E/SE are replaced by
  approved unlit base-idle rows because the master introduced an eye-like warm
  visor reflection.
- `ultidle_ne_v01_rejected_crop.png`: rejected because f4 clipped the tip.
- `ultidle_ne_v02_keyed_5source.png`,
  `ultidle_n_v01_keyed_5source.png`: four live frames plus disposable safety
  pose; complete inward-staged blade in frames 1-4.
- `death_v01_rejected_sword_gap.png`: rejected because the sword vanished
  during the grounded transition.
- `death_v02_keyed.png`: nine-frame coherent collapse; the same complete sword
  transfers from right hand to ground and remains visible through the held
  corpse.

## Deterministic conversion notes

The builder reuses the Paladin pipeline's chroma/despill, fixed-reference
normalization, and shared staging geometry. Warrior additionally uses
connected-silhouette extraction: long diagonal swords overlap neighboring
poses in X even when green separates the silhouettes, so a vertical gutter
can move a sword tip into the next frame. A lightly bridged connected-component
mask isolates each whole body+weapon before normalization.

The build hardens alpha, zeros transparent RGB, validates every frame is
non-empty, validates frame counts/geometry, removes temporary directional
death derivatives, and asserts the exact historical 74-PNG Warrior contract.

## Archive

The exact pre-replacement 74 Warrior PNGs are preserved locally under:

`backup/warrior_base_pre_emberbound_heir_2026-07-31/`

`SHA256SUMS.txt` records every original. Copy verification reported
`74 archived, 0 mismatches`.
